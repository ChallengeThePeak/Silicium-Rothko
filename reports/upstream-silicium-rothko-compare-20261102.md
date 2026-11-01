# 上游 Silicium-Rothko 对比结论（2026-11-02）

对比对象：`git@github.com:ChallengeThePeak/Silicium-Rothko.git`（私有，经 WSL SSH 克隆）
对比基准：本地 `/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean`
（`0b5a75c`）与 `Mu-Silicium-fv-membership-fixed`（`544ac2d6`）

证据等级标注：**实测**=本次克隆/读取得到；**文档声明**=上游 README/构建文档自述；
**条件推导**=由文件结构推得；**未知**=无证据。

## 1. 克隆与仓库状态（实测）

- WSL 内 HTTPS 匿名访问返回 401/404：`ChallengeThePeak` 是组织账号，
  `public_repos: 0`，仓库私有。
- 改用 WSL 既有 SSH 密钥（`~/.ssh/id_ed25519_wsl`，`ssh -T` 回 `Hi woaphone!`）成功。
- 直连速度约 30 KB/s，58% 处 `early EOF`；改走 Windows 代理（Clash `127.0.0.1:7897`，
  经 TCP 中继暴露到 `172.30.32.1:15537`，SSH 用 `ProxyCommand` 做 HTTP CONNECT）
  后稳定在 2.5 MB/s。

克隆结果（`/home/ubuntu/rothko-upstream-20261102/`）：

| 内容 | 位置 | 提交 |
| --- | --- | --- |
| 主仓库文档/工具 | `Silicium-Rothko/`（depth 1 + deepen 80） | `6b1f2dde01170b242f001726fc3f686cde250019` |
| UEFI 平台源码 | `uefi-src/`（sparse，`uefi/rothko`） | `3b336382d620adecade8d4b2110e8b8b7db496e9` |
| Basecore 源码 | 未克隆（`basecore/rothko`） | `cd48f4d6e5220c3791ec169caafb08be63a3a734` |

其余引用：`uefi/rothko`、`basecore/rothko` 两个源码分支；标签
`rothko-avb-v1`=`2e21155`、`rothko-trace-v2`=`949afd3`、
`uefi-avb-v1`=`4677e07`、`uefi-trace-v2`=`8ec4559`、
`basecore-avb-v1`=`cd48f4d`、`basecore-trace-v2`=`9918480`。

提交时间线（实测，`main`）：11-01 14:54 / 14:56 / 15:07 / 15:29 / 15:57。
**本仓库是本项目今天下午（本地计划最后更新 12:21 之后）发布的私有镜像，
与本地 Mu-Silicium 树并不同源。**

## 2. 上游自述的运行状态（文档声明）

`BUILD_PSTORE_BOOT.md` 记录的实机低日志版本输出：

```text
K70U_UEFI_PSTORE_BEGIN
MMU: enabled
SEC: HOB list ok, 134 entries
SEC: FV decompressed (Success)
SEC: loading DXE core
Loading DxeCore at 0x0040E58000 EntryPoint=0x0040E5A800
ASSERT [DxeCore] Gcd.c(2420): Found
```

即以 `uefi-mtk-reference` + UniXNU 路线，已经越过 LK、BootShim、SEC、FV 解压，
**进入 DXE Core 并在 GCD 断言处停止**。上游明确把下一步指向
“DXE 内存资源 / HOB 属性问题”，而不是 framebuffer 黑屏或 boot 未执行。

取证通道是 **pstore**：`Sec.c` 早期写 `K70U_UEFI_PSTORE_BEGIN`，
DEBUG 的 `DebugLib` 接 `BaseDebugLibSerialPort`，`SerialPortLib` 接
`FrameBufferSerialPortLib`（先写 pstore 再尝试 framebuffer），
pstore 区 `0x48090000+0xE0000`、pmsg `0x480F0000+0x80000`，
读取方式是恢复 Android 后 `cat /sys/fs/pstore/pmsg-ramoops-0`。
实机通道为 Antumbra/DA，而不是 `fastboot boot` 或 ADB。

## 3. 与本地树的实质差异（实测）

| 维度 | 上游 `uefi/rothko` | 本地 `Mu-Silicium-*` |
| --- | --- | --- |
| 平台包成员 | 11 个文件，含 `Library/MemoryMapLib/`、`UniXNUComponents.dsc/fdf.inc`、`UniXNUConfig.dsc.inc` | 5 个顶层项，含 `Drivers/RothkoDisplayDxe`、`Drivers/RothkoWatchdogDxe`，无 UniXNU 组件 |
| `Include/DXE.inc` | 31 行，30 条 INF，含 `UniXNUPkg` 两个驱动、`GraphicsConsoleDxe`、`BdsDxe`、`FatPkg` | 41 行，含自研 `RothkoWatchdogDxe`/`RothkoDisplayDxe` 两条（fvfix 后） |
| `Include/APRIORI.inc` | 14 条，只排标准 DXE + `UniXNURamDiskDxe` | 引用自研驱动 GUID |
| pstore 日志代码 | 有（`Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/`） | **完全没有**（全树 grep `PstoreLog`/`K70U_UEFI_PSTORE_BEGIN` 无命中） |
| 显示 | 标准 `GraphicsConsoleDxe`，黑屏不影响日志 | 自研 `RothkoDisplayDxe`（需先于 GraphicsConsole 拿到 GOP） |
| 取证方式 | pstore pmsg + DA 读 expdb/blackbox | 只靠 expdb/AEE 考古 |

**结论：两条独立血统。** 本地是“Mu-Silicium + 自研显示/看门狗驱动”路线，
上游是“uefi-mtk-reference（uefi-malachite）+ UniXNU + pstore”路线。

## 4. 对既有结论的影响

1. **本地已修的 FV 封装缺陷只对本地分支成立。** 上游 `rothkoPkg` 根本没有
   `RothkoDisplayDxe` / `RothkoWatchdogDxe`，也没有 `Drivers/` 目录，
   因此“DXE.inc 漏列两条 INF 导致 FFS 缺失”这件事在上游不存在，
   不存在“上游是否已修”的问题。`544ac2d6` 仍是本地分支上的有效修复，但不构成上游的进展差。
2. **本地运行时证据明显落后。** 本地最强证据是入口探针
   （`PC=0x40000070`，shim `_Park`），只证明 BootShim 被执行，
   从未证明进入 SEC/DXE。上游已经有 6 行阶段日志到 DXE Core。
3. **取证路线应换。** 本地一直用 expdb/AEE 反推停点，多次因为
   “缺字符串 ≠ 没执行”而反复。上游的 pstore 方案直接把阶段日志写到 RAM，
   是目前唯一在本机证明确实可读的通道。

## 5. 上游自己仍未解决的关卡（文档声明）

- `uefi/rothko` 当前止于 `Gcd.c(2420)`，属 DXE 内存资源/HOB 属性问题。
- UFS：恢复出的 LK 在直接跳 UEFI 前会 `ufs_deinit()` 静默 UFS，
  UEFI 侧尚无可用 MT6989 UFS 读路径；XNU 侧还要另做 DMA/SMMU/IOStorageFamily。
- 载荷容量：8 MiB `init_boot` 装不下完整 XNU；`vendor_boot_b` 方案未落地。
- MT6989 在 UniXNU 既有移植中不存在（只有 MT6765/6768/6833/6835/6878）。
- panel/touch、PMIC、GPU、Wi-Fi、audio 变体均未确认。
- AVB 尾保留 ≠ 重签，仅在当前解锁设备 + 实测 LK 策略下有执行证据。

## 6. 建议的下一步（待用户选择）

- **A. 切到上游路线**：以 `uefi/rothko` + `basecore/rothko` + UniXNU 为基线复现，
  把火力集中在 `Gcd.c(2420)` 的 GCD/HOB 断言。
- **B. 只移植 pstore**：保留本地 Mu-Silicium 驱动路线，把
  `PstoreLog` + `FrameBufferSerialPortLib` + pmsg 区搬进来，换取实机阶段日志，
  再判断本地停点到底在哪。
- **C. 继续本地 expdb 路线**：不推荐，已经反复出现“缺字符串被误读为没执行”。

本轮未做任何设备操作、未刷写、未改动本地既有源码树与镜像。

## 7. 上游的启动与打包链（实测源码 + 文档）

### 7.1 总路线
不改 preloader / LK / vendor_boot / dtbo，只写两个分区：
`boot`（v4，kernel 字段放 BootShim+UEFI）和 `init_boot`（v4，ramdisk 字段放裸 FAT）。
正常重启进 LK，不使用 `fastboot boot`。

### 7.2 容器层三个关键决定（`tools/boot_v4.py`，378 行）

1. **保留 AVB 尾部** `--preserve-avb-tail`（默认关闭，本流程开启）。
   尾部起点 = `0x1000 + align(kernel_size) + align(ramdisk_size)`（stock 头里的原始尺寸），
   从该处把模板剩余字节原样搬过来。旧版 `build_v4()` 只拷前 4096 字节、后面清零，
   于是 GKI 两张证书（`0xFC9000`）、设备 VBMeta（`0xFCD000`）、`AVBf` 尾（`0x3FFFFC0`）全丢。
   仍要求新载荷不得越过尾部起点。
2. **复用 stock 的 v4 头**：直接取模板前 4096 字节，只 patch 偏移 8/12 的
   `kernel_size` / `ramdisk_size`；`check_boot_template()` 强制 `header_version=4`、
   `header_size=1584`、偏移 1580 的 `signature_size==0`（非零 GKI 签名区直接报错不支持）。
3. **压缩用 legacy LZ4**（`0x184C2102`，8 MiB 块，`LZ4_compress_HC` level 12），
   与 stock 一致，而不是 gzip；校验时两种都支持。

### 7.3 载荷层
- `boot`：`kernel = legacy_lz4(BootShim + FD)`，无 ramdisk。FD 2 MiB，`FD_BASE=0x40400000`。
- `init_boot`：`kernel` 空，`ramdisk = 1 MiB 裸 FAT12`（要求 512 对齐 + `0x55AA` 签名），不压缩。
- `kernel_target` 从 `vendor_boot` 偏移 16 读取（0x40000000），不是写死的。

### 7.4 BootShim（`BootShim/BootShim.S`）
`_Head: adr x1,_Payload; b _Start` → 56 字节 ARM64 Image 头 →
`_Start` 以 `ldp/stp` 16 字节步长把 `FD_SIZE` 从 `_Payload` 拷到 `FD_BASE` →
`dsb sy` + 按 CTR_EL0 行大小 `dc cvac` 清 D-cache + `ic iallu` + `dsb/isb` → `br x5` 跳 FD 基址。
FD 必须 16 字节对齐（打包脚本检查）。

**语义修正**：原来 `text_offset` 被写成 `FD_BASE`（0x40400000），而 ABI 里该字段是
相对 2 MiB 对齐基址的**装载偏移**，不是重定位目的地。新包装器归一化为
`kernel_target % 0x200000 = 0`，并把 `flags` 设为 `0xA`，不改共享的上游 shim 编译器。
同时 `validate_bootshim_ranges()` 拒绝“FD 拷贝目标与活体镜像部分重叠”。

### 7.5 固件侧配套 PCD
`UniXNUConfig.dsc.inc`：
`PcdUniXNURamDiskOffset = 0x02719743`（= vendor_boot 中 normal type-1 ramdisk 的
压缩字节数，由 `normal_vendor_ramdisk_size()` 解析得出），
`PcdUniXNURamDiskSize = 0x00100000`（FAT 实际大小）。
偏移是 LK 拼接后 FDT initrd 里 FAT 前面的 vendor ramdisk 长度，
**不是分区内文件偏移，也不做页对齐**；不能把整个 initrd 暴露给 XNU。

### 7.6 为什么这套能过 LK
LK 的 AVB 路径（反汇编 `0xA4EFC..0xA528C`）区分“验证错误”和“元数据非法”：
前者在允许时可继续，后者直接判 invalid。保留 footer 与 VBMeta 结构，
即使 payload hash 已过期，也走“验证错误可继续”分支；丢 footer 会让它去读偏移 0，
那里是 `ANDROID!` 而不是 `AVB0`。
审计同时声明：**缺 footer 的因果未证**（正确化的 tiny probe 同样失败），
尾部保留也**不是重新签名**，报告必须同时显示
`avb_tail_preserved: true` 与 `avb_payload_resigned: false`。

### 7.7 “启动”被看见靠的是 pstore，不是显示
日志走 `Sec.c` → `PstoreLogBegin()` → `BaseDebugLibSerialPort` →
`FrameBufferSerialPortLib`（先写 pstore 再试 framebuffer），
pstore 区 `0x48090000+0xE0000`，pmsg `0x480F0000+0x80000`，
12 字节头（`DBGC` + 写指针 + 有效长度），追加不清空。
黑屏不影响这条路，恢复 Android 后 `cat /sys/fs/pstore/pmsg-ramoops-0` 即可。
