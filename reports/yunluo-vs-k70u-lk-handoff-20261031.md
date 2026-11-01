# yunluo 成功案例与 K70U LK 交接对照（2026-10-31）

## 结论先行

yunluo 的可用案例有明确的 LK→kernel 证据：expdb 出现
`boot_linux_fdt:547: kernel_sz=...` 和
`boot_linux_fdt:749: decompress kernel image...`；上游记录还明确说明该
Mu-only 镜像能进入 UEFI Shell。

K70U 当前设备 expdb 最新尾部只到：

```text
starting app mt_boot
wait_for_boot_linux:1009: Wait for boot linux event...
```

随后是 CCCI modem 加载，没有 `boot_linux_fdt`、`kernel_load_addr`、
`decompress kernel image`、`booting linux @` 或 `lk finished --> jump to linux kernel`。
所以当前记录没有证明 LK 已经拿到候选 boot.img，更没有证明已经跳到
BootShim/UEFI；它证明的是 LK 仍停在等待 boot_linux 事件的路径。

## LK 反编译给出的硬条件

stock K70U `lk.img` 的 `sub_FFFF00005070FC00`（保存于
`work/evidence-20261031/stock-lk/ida-lk-first.json`）对应 `boot_linux_fdt`：

1. 读取 kernel size，打印 `boot_linux_fdt:547`。
2. 找到主 DTB 后打印 `64 bits kernel`、`dtb_addr` 和
   `kernel_load_addr`（约 589–633 行）。
3. 要求 `mb_dtb` 存在且 DTB 地址与 reserved memory 一致；失败走
   `vm_dtb`/`kernel_addr` 错误分支。
4. 要求 `mb_kernel` 存在且其起始地址等于 kernel load address；否则打印
   `kernel_addr ... is not taken from mb`。
5. 打印 `decompress kernel image...`（约 749 行），解压 gzip kernel。
6. 设置 initrd start/end，更新 DTB，执行 `booting linux @ ...`，最后打印
   `lk finished --> jump to linux kernel ...` 并跳转。

这说明需要验证的是 LK 的 `boot_linux_fdt` 是否被进入，以及它拿到的
kernel/DTB/reserved-memory 三元组是否一致；不能只看 Android header 或
BootShim 自身校验。

## yunluo 成功证据

保存的 `raw-captures-late.json` 与 `raw-captures-22-24.json` 中可见：

```text
boot_linux_fdt:547: kernel_sz=0x00048381
boot_linux_fdt:749: decompress kernel image...
```

对应的 yunluo 文档记录：Mu-only Android boot v4 镜像能进入 UEFI Shell；
该参考镜像使用 7 MiB FD、`FD_BASE=0x50000000`，并且 BootShim+FD 回读一致。

## K70U 候选的静态契约

当前候选 `.img` 已通过 Android v4、gzip、BootShim ARM64 header、
`text_offset=0x42000000`、BootShim+2 MiB FD 长度校验。stock K70U expdb
的 `mb_kernel` 是 `0x40000000` 起始，大小 `0x07c80000`；因此候选 BootShim
从 LK kernel load address 启动，再把 FD 搬到 `0x42000000`，静态地址关系是
自洽的。

这只能证明候选满足 LK 可能接受的容器/地址契约，不能证明设备已执行它。
当前设备 `sys.boot_completed=1`，expdb 又包含多段历史启动片段；本次采集
没有把候选 `.img` 送进 LK，因此不能用缺少 handoff 行反推候选代码已经失败。

## 实锤下一步

在设备上临时启动候选 `.img` 后，必须在同一轮 expdb 中看到至少：

```text
boot_linux_fdt:547: kernel_sz=...
boot_linux_fdt:749: decompress kernel image...
boot_linux_fdt:847: booting linux @ ...
boot_linux_fdt:850: lk finished --> jump to linux kernel ...
```

若只看到 `wait_for_boot_linux`，问题仍在 LK 事件/boot image 选择之前；若看到
`kernel_addr ... is not taken from mb`、`vm_dtb`、`decompress kernel` 错误，才进入
候选镜像地址、DTB、gzip 或 AVB 分支。该临时启动需要单独的设备操作授权，
本轮没有执行。


## K70U 失败现场的 fastboot 分支证据修正（2026-10-31）

正常 K70U `/proc/pl_lk` 也先执行 fastboot app/`wait_for_enter_fastboot`，然后打印 `Ready to boot linux...` 并加载正常镜像。因此 expdb 中的 `wait_for_boot_linux` 本身不是候选未加载的充分证据。

失败 expdb 的两段序列各自记录 home 键按下、`boot_reason=1`、`notify_enter_fastboot`；之后虽然启动了 `mt_boot` 并等待 boot_linux event，但没有正常启动记录的 `Ready to boot linux...`，也没有任何 boot header 加载或 `boot_linux_fdt`/kernel handoff 标志。这把故障定位到 LK 尚未观测到 boot_linux 事件的分支；不支持据此判定候选头、vbmeta 或 UEFI 代码有错。`/proc/pl_lk` 正常样本按键采样为未按下且 `boot_reason=4`，是有价值的对照。

若当时没有按 home 键，需调查 LK 为什么采到该键状态；当前静态记录无法区分实体键/电平/输入事件来源，也无法证明一次 fastboot `boot` 命令是否成功发出。
