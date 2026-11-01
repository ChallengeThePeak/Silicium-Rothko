# K70U UEFI 修复离线实锤

> 2026-11-01 继续核对后的更正：本文为上一轮历史记录，不再作为“根因已修好”或
> “fresh keepalive 已重编”的证明。AEE23 只保存 FAR 低 24 位，Buffer=9 是有条件推导；
> 已交付 confirmed 镜像与 stage-coded 镜像同字节，仍含 600 次回调后停喂狗的诊断限制。
> 所引用 build-staged-01/result.json 的 FD 哈希与实际产物也不一致。
> 新结论与独立重编记录见 continuation-20261101.md；本文旧产物与原始记录保留。

## 结论

历史 AEE23 记录已经把旧 UEFI 的崩溃原因收敛到 DxeCore 的池释放路径：

1. AEE/TFA 记录的诊断信标是 PC 0x43784d58、LR 0x2543b86bd4fffff1、FAR 低 24 位 0xfffff1、EC 0x25。
2. DxeCore 的运行基址为 0x43b7f000；其 map 把 CoreFreePoolI 放在 RVA 0x7ba0。历史 ELR 0x43b86bd4 落在这个函数内。
3. CoreFreePoolI 的关键指令是 ldr w26, [x20, #-0x18]!. FAR 为 0xfffffffffffffff1 时，传入的 Buffer 是 9。
4. 所以旧故障是 FreePool((VOID *)9) 进入 CoreFreePoolI 后读取伪造池头，触发同级 Data Abort，随后看门狗只负责收尸。

这条因果链与 expdb 中的 AEE header、TFA_DEBUG_BUF.gz、DxeCore map 和反汇编互相闭合。home-key、vbmeta HASH_MISMATCH 和 LK 等待记录不是这次 UEFI Data Abort 的根因。

## 修复证据

当前 staged 构建源码包含并通过构建：

- 0003 pool hardening：CoreFreePool 在进入 CoreFreePoolI 前拒绝低于 0x1000 或非 8 字节对齐的指针。
- BmConsole 的 TempDevicePath 双重释放修复。
- GraphicsConsole 的 LineBuffer 释放后置空。
- BmDriverHealth、BmMisc 的 bring-up warm-reset 路径移除。
- 0001 SEC 入口修正：SPSel、跨 LK 的数据缓存清理、x0 入口 HOB、stack/FD write-back invalidate。
- GICD 0x0c400000/0x40000、GICR 0x0c440000/0x200000，以及显示 MMIO 页对齐映射。
- staged phase markers 和独立 RothkoWatchdogDxe；SEC、GIC、Timer、watchdog、display 各阶段都有可读的 WDT LENGTH 代码。

当前构建的 DxeCore 反汇编直接显示：

- CoreFreePool 的低指针检查：cmp x0, #0x1000，低于该值直接返回。
- 未对齐检查：and x8, x20, #0x7，非零直接返回。
- 只有通过检查后才调用 CoreFreePoolI。

## 交付镜像

- [boot-rothko-uefi-confirmed-20261101-avbf.img](../work/evidence-20261031/boot-rothko-uefi-confirmed-20261101-avbf.img)
- 大小：64 MiB
- SHA-256：18eced1a56c33b9b34d35d037cb2f8b97832f6bf704638d1cd28fa9cc7b78a16
- Android boot v4，gzip kernel 296322 B
- 解压后：256 B staged BootShim + 2 MiB UEFI FD
- UEFI FD SHA-256：d55a4f9d5cb5a85475c810f8b4824ac50a0c723486e667ee867650b30a847948
- AVBf 分区大小 0x4000000，AVB0 hash descriptor 424 B，digest_ok=True

离线验证通过：

- Android v4 header、gzip、ARM64 header、FD_BASE 0x42000000、FD 大小 2 MiB。
- AVBf footer 和 SHA-256 digest。
- gzip 回拆后 FD 与 staged 构建 FD 完全一致。
- SEC.efi 反汇编包含 0x5008、0x5808、0x6008、0x6808、0x7008、0x7808、0x8008 阶段值。
- ArmGicDxe、RothkoWatchdogDxe、RothkoDisplayDxe 反汇编包含对应阶段值。

配套低校验 vbmeta 仍是：

- [vbmeta-avb-disabled-flags3.img](../bringup/vbmeta-avb-disabled-flags3.img)
- flags=3，SHA-256 1fc27c867cc4b8045b35ad0c01c4702beeecb426f3472174ef35e75d515136b4

## 证据边界

根因、源码修复、构建产物、BootShim/UEFI 封装和 AVB digest 已经离线实锤。当前没有把这份新镜像刷入设备，因此“真机已经成功进入 DXE/BDS”仍需要一次刷入后的 expdb；这不是容器或源码验证可以替代的部分。
