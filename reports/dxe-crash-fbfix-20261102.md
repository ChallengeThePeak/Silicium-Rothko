# DxeCore 同步异常定位与修复（2026-11-02）

## 1. 实机现象（pstore）

```
FV Hob            0x40400000 - 0x405FFFFF

Synchronous Exception at 0x0000000040E59528
PC 0x000040E59528 (0x000040E58000+0x00001528) [ 0] DxeCore.dll
Recursive exception occurred while dumping the CPU state
```

## 2. 符号解析（实测）

```
0x1528 -> ArmCleanInvalidateDataCacheEntryByMVA
    1528:  dc  civac, x0
    152c:  ret
```

`WriteBackInvalidateDataCacheRange()` 在 AArch64 上正是逐行 `dc civac`。
该库被静态链进 DxeCore，所以 PC 落在 `DxeCore.dll+0x1528`。
`dc civac`（按 MVA 的缓存维护）在目标地址**未被地址翻译**时会触发同步异常，
这与 `Synchronous Exception` 完全吻合。

## 3. 根因

`Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c`
的 `GetFrameBufferMemory()`：

```c
EFI_MEMORY_REGION_DESCRIPTOR FbRegion;          // 未初始化

LocateMemoryRegionByName ("Display Reserved", &FbRegion);
LocateMemoryRegionByName ("Display_Reserved", &FbRegion);
if (!FbRegion.Address && !FbRegion.Length) {    // 检查的是栈垃圾
  return EFI_NOT_FOUND;
}
```

而 `MemoryMapHelperLib.c` 中 `LocateMemoryRegionByName()` 在找不到时**直接 `return EFI_NOT_FOUND`，
完全不写输出参数**。

本平台的 `gMemoryDescriptor`（`rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c`）里
**没有任何名为 `Display Reserved` / `Display_Reserved` 的条目**，所以两次查找都失败，
`FbRegion` 保持栈垃圾；`if` 判断的是垃圾值，大概率通过，于是把垃圾当成 framebuffer 基址返回。

`SerialPortWrite()` 随后：

```c
WriteBackInvalidateDataCacheRange ((VOID *)mFbGeometry.Base, FB_PITCH * FB_HEIGHT);
```

对垃圾地址做缓存维护 → 同步异常。
异常处理程序 `DefaultExceptionHandler` 又要 `DebugPrint` 打印寄存器 →
再次进入 `SerialPortWrite` → 再次对同一个垃圾地址 `dc civac` → **递归异常**，
因此 ESR / FAR / 寄存器快照全部丢失。

**重要含义**：这次"崩溃"发生在日志路径内部，不是 DXE 真正执行到某个业务代码才挂。
修掉之后，DXE 很可能还能继续往下走。

## 4. 修复（两处）

`FrameBufferSerialPortLib.c`：

1. `GetFrameBufferMemory()`
   - `FbRegion` 改为 `= { 0 }`；
   - 用 `EFI_ERROR()` 检查两次查找的返回值，都失败则返回 `EFI_NOT_FOUND`；
   - 再补一层 `Address == 0 || Length == 0` 的防御。
2. `SerialPortWrite()`
   - 刷新前校验 `mFbGeometry.Base` 落在 `[FbBase, FbBase + FbLength)` 内；
   - 刷新长度用 `PitchBytes * Height`，并钳制到 `FbLength`。

原文件备份：`/home/ubuntu/quarantine/FrameBufferSerialPortLib.c.orig-*`。

行为变化：本平台没有显示保留区，日志只走 pstore，不再尝试 framebuffer。
这正是上游文档所说的"黑屏不妨碍这条输出路径"，而且现在不会再被 framebuffer 拖崩。

## 5. 本版镜像

| 文件 | 大小 | SHA-256 |
| --- | ---: | --- |
| `bringup/boot-k70u-uefi-pstore-fbfix-20261102.img` | 67108864 | `5c66e04504d024b9dd45d2e61812778d83efcbc30d81b21fcf2ff532d4de616f` |
| `bringup/init_boot-k70u-uefi-pstore-fbfix-20261102.img` | 8388608 | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/SILICIUM_UEFI-pstore-fbfix-20261102.fd` | 2097152 | `3c5098133a6460306c0cbfbab1e79c0ec44f3317366552d3e903e2d6c25180bd` |

`Gcd.c` 的 `K70U-GCD` 调试转储仍保留。

## 6. 下一轮判据

- 若日志越过 `FV Hob` 且不再出现 `Synchronous Exception` → DXE 在继续，观察后续阶段/新断言；
- 若仍异常但 PC 变了 → 按同样方法用 `llvm-symbolizer` 解析新 RVA；
- 若出现完整寄存器转储（不再递归）→ 直接看 `ESR`/`FAR`/`ELR`，定位会快很多。

本镜像未实机验证；刷写由用户执行。
