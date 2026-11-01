# K70 Ultra UEFI 候选（2026-10-31）

## 结果

已完成独立候选源码的离线构建。最终固件位于：

- `work/evidence-20261031/build-20261031-03/firmware.fd`
- `outputs/rothko-k70u-uefi-evidence-20261031.fd`
- `outputs/rothko-k70u-uefi-evidence-20261031.img`

SHA-256：`65450d31fd30072e02ceab512d4f1fb1e64a5f66732267ed16d6527051001f44`。
大小为 2,097,152 字节。构建源码快照提交为
`10a14f37eb327477deb7b4f9b45b9381743aaef4`，使用 Ubuntu2404、clang 18.1.3、
AARCH64 DEBUG/CLANGPDB，构建返回码为 0。

Windows 侧独立 overlay 已提交为 `af0802a2`（平台修正）和 `f81957e6`
（watchdog DXE）。

`.img` 使用现有 BootShim + Android boot header v4 封装器生成，大小为
307,200 字节，SHA-256 为
`a9b39f2a29dc06a401c1fc52b490f4c931bed5f3609c097acdf3d28e941f76a9`。

## 已落地的修正

- GICD/GICR 改为原始 DTB 证实的 `0x0c400000` / `0x0c440000`，并覆盖
  标准窗口；原 DTB 的 `arm,gic-v3` reg cells 是 `0xc400000/0x40000` 和
  `0xc440000/0x200000`。
- 内存图补齐 watchdog、AUX mutex 和显示访问所需的页对齐 MMIO 区域。
- watchdog 独立为 `RothkoWatchdogDxe`，在 TimerDxe 后以 TPL_NOTIFY 周期性
  写入 MTK RGU restart key；没有改变 LK 交给 UEFI 的 MODE/reset 路由。
- 显示驱动增加 framebuffer、stride、矩形和 DTB 头边界检查；DSI 忙时保留
  dirty 状态，不重启仍在运行的传输。

## 验证

- `work/evidence-20261031/build-20261031-03/edk-report.txt` 明确列出并链接
  `RothkoWatchdogDxe` 与 `RothkoDisplayDxe`。
- `build.log` 中没有 `error:`，只有一条既有的
  `ArmPsciResetSystemLib`/`HwResetSystemLib` 类告警。
- `scripts/check-memmap-alignment.py` 对全部描述符通过；GIC、watchdog 和
  display 区域均为 4 KiB 对齐。
- 固件开头包含 FV header；现有 `list-fv.py` 对此布局报 0 个 named FFS，故
  模块是否进入 FV 以 EDK build report 为依据，没有把该脚本结果误报成成功。
- `verify-bootimg.py` 对 `.img` 返回 `result: OK`：Android magic、gzip 页对齐、
  ARM64 BootShim、`FD_BASE=0x42000000`、BootShim+2 MiB FV 长度全部通过。

## 证据边界

历史 AEE/ATF 记录确认的是：进入 DXE 异常处理器后发生 Data Abort，随后约
33 秒 watchdog 超时；GIC 地址不一致和未映射显示 mutex 是源代码与原 DTB
之间的实锤契约错误。这些修正解释并针对已观测故障，但不等于已经证明硬件
首次启动成功。

本轮没有连接设备，也没有刷写、启动、复位或修改分区。watchdog IRQ 是否在
目标硬件上持续送达、面板时序、内存属性以及 Android handoff 仍需用户明确
授权后在实机上验证。


## AVBf 候选变体（离线生成）

参考第三方同 SoC handoff-stage 的规范 AVB0/AVBf helper，并按 expdb 中 `boot_a`
大小 `0x4000000` 生成了独立容器变体：

- `work/evidence-20261031/boot-rothko-uefi-evidence-20261031-avbf.img`
- SHA-256 `2537c3b5e01b08f870dfb39a7a0836e04b24406352fdfb3b95a104be4d27a295`
- 64 MiB，AVBf v1.0，AVB0 hash descriptor 424 B，digest verified
- 原始 body、UEFI FD、BootShim 均未改动；仅添加分区填充和 AVB footer/vbmeta

这提供了一个可和原 307,200 B 候选分别验证的镜像容器版本。它尚未刷写或启动，
也不能单独证明顶层 vbmeta 链策略已经允许该 unsigned AVB0。


## 固化低校验打包器

新增 `src/uefi-rothko-evidence-20261031/scripts/pack-bootimg-rothko-avb.py`：默认先生成 v4
body，再按 `boot_a=0x4000000` 自动追加规范 AVBf/AVB0；`--no-avb` 仅用于离线对比。
它拒绝覆盖已有 body/output，避免把旧候选混入新构建。
