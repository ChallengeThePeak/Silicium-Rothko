# Gcd.c 断言的根因与修正（2026-11-02）

## 1. 实机证据（pstore，Debug 版）

```
K70U-GCD: PhitFreeBottom=0x40681C48 PhitFreeTop=0x40E58000 PhitMemTop=0x41680000 Found=0
K70U-GCD: RD base=0x40680000 len=0x1000000 type=0x0 attr=0x703E07   <-- 覆盖 PHIT 范围
...
ASSERT [DxeCore] Gcd.c(2448): Found
```

- `type=0x0` = `EFI_RESOURCE_SYSTEM_MEMORY`，`type=0x1` = `MEMORY_MAPPED_IO`，`type=0x5` = `MEMORY_RESERVED`。
- `0x40680000 + 0x1000000 = 0x41680000`，**完全覆盖** `PhitFreeBottom..PhitFreeTop`
  （`0x40681C48..0x40E58000`）。

**结论：不是内存缺口，是属性判定失败。**

## 2. 判定条件（`Gcd.c` `CoreInitializeMemoryServices`）

```c
if (ResourceHob->ResourceType != EFI_RESOURCE_SYSTEM_MEMORY) continue;
if ((ResourceHob->ResourceAttribute & MEMORY_ATTRIBUTE_MASK) != TESTED_MEMORY_ATTRIBUTES) continue;
if (PhitHob->EfiFreeMemoryBottom < ResourceHob->PhysicalStart) continue;
if (PhitHob->EfiFreeMemoryTop   > ResourceHob->PhysicalStart + ResourceHob->ResourceLength) continue;
Found = TRUE;
```

`TESTED_MEMORY_ATTRIBUTES` = `PRESENT|INITIALIZED|TESTED` = `0x7`，且用的是**等值比较**。
实测 `attr=0x703E07`，掩码后仍带着 `UNCACHEABLE|WC|WT|WB|EXECUTION_PROTECTED`，不等于 `0x7`，
所以每一条 `SYSTEM_MEMORY` 描述符都被 `continue` 掉，`Found` 永远是 0。

## 3. 根因

`Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c` 的 40 条系统内存条目
统一使用 `SYS_MEM_CAP_XN`：

```c
#define SYS_MEM_CAP_XN  (SYSTEM_MEMORY_RESOURCE_ATTR_CAPABILITIES | EFI_RESOURCE_ATTRIBUTE_EXECUTION_PROTECTED)
```

这是“**具备**这些能力”的集合，适合描述能力，不适合作为资源描述符的“实际属性”。
`Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c:93` 把该字段**原样**
传给 `BuildResourceDescriptorHob`，没有任何掩码，于是 `0x703E07` 直接进了 HOB。
EDK2 官方平台一律只写 `PRESENT|INITIALIZED|TESTED`。

## 4. 修正

改**生产者**，不动 core：

```c
// [k70u-fix 2026-11-02]
#define SYS_MEM_TESTED (PRESENT | INITIALIZED | TESTED)
```

表内 40 处 `SYS_MEM_CAP_XN` → `SYS_MEM_TESTED`。

不受影响的部分：
- 表最后两列（`WRITE_BACK` / `WRITE_BACK_XN` 等）驱动 ARM MMU 页表，与 HOB 属性无关；
- `Pstore` 条目用的是 `MEM_RES + UNCACHEABLE`（`type=0x5`），Gcd 该检查只筛
  `SYSTEM_MEMORY`，不涉及；
- `GIC` 两条是 `MMAP_IO`，同样不涉及。

原文件备份：`/home/ubuntu/quarantine/MemoryMapLib.c.orig-*`。

## 5. 新镜像

| 文件 | 大小 | SHA-256 |
| --- | ---: | --- |
| `bringup/SILICIUM_UEFI-pstore-memfix-20261102.fd` | 2097152 | `e77c7d34d32c314d33e0235e41ac2917f27ed975cc6177b1dda293f86f42217d` |
| `bringup/boot-k70u-uefi-pstore-memfix-20261102.img` | 67108864 | `b88c02459118b880696dcf35b4da6ce73fe85634ab93cd0f45223a697f36f73c` |

`Gcd.c` 里的 `K70U-GCD` 调试转储**保留**，下一轮还能直接看到表内容。

## 6. 下一轮判据

- 若 `Found=1` 且不再在 `Gcd.c` 断言 → 继续往下看 DXE 后续阶段日志；
- 若仍在 `Gcd.c` 断言但行号变化 → 是同一函数里后续的另一个检查（如
  `CoreAddMemoryDescriptor` 或内存类型信息），按同样方式读断言上下文；
- 若出现新的断言/挂死 → 记录新的模块与行号，继续用 pstore 定位。

本镜像未实机验证；刷写由用户执行。
