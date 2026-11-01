# expdb LK→Linux 交接检查（2026-10-31）

## 读取对象

- 设备：`VKMZZDEI4H759TRS`，只读 adb/root shell。
- `ro.boot.bootreason=reboot`，`ro.bootmode=normal`，当前 `sys.boot_completed=1`。
- `expdb` 大小：128 MiB；读取最后 8 MiB 到
  `work/evidence-20261031/logs/device-expdb-tail8m-20261031.bin`。
- 用户确认：该 expdb 是把本候选镜像刷入设备后连续启动两次失败，随后刷回
  原系统再提取的现场；因此最新重复 LK 序列按候选刷入后的失败证据处理。
- 本次重新从设备完整只读抓取 128 MiB：
  `work/evidence-20261031/logs/device-expdb-full-after-flash-20261031.bin`，
  SHA-256 `e374ed83b0e7e6b9d3f992fefcd57673769f34554352b62126814a8a05241ace`。

## stock LK 应有的交接标志

从用户提供的 stock `lk.img` 字符串表确认存在：

- `Notify boot linux.`
- `booting linux @ 0x%llx, ramdisk @ ... dtb @ ...`
- `kernel_load_addr=...`
- `Ready to boot linux...`
- `64 bits kernel`
- `lk finished --> jump to linux kernel ...`

## 实际最新 expdb 尾部

最新一组（尾部相对偏移约 `0x7fc48c`）出现：

1. `starting app mt_boot`
2. `wait_for_boot_linux:1009: Wait for boot linux event...`
3. `CCCI` modem image load/auth 完成
4. 日志结束

在这两组最新等待序列及完整 128 MiB 抓取中，没有找到：

- `Notify boot linux`
- `booting linux @`
- `kernel_load_addr=`
- `Ready to boot linux`
- `64 bits kernel`
- `lk finished --> jump to linux kernel`

完整抓取中的两条 `partition magic error` 都紧跟在
`Load 'pi_img_a'` / `load kraken` 之后，属于 LK 的 pi_img/kraken tinysys
加载支路，不是 `boot.img` 的 kernel handoff 报错，不能拿来替代
`boot_linux_fdt` 失败证据。

## 结论

可确认的卡点是候选刷入后的 LK `mt_boot` 应用等待 `boot_linux` 事件，尚未
进入 Linux 64-bit kernel 的装载/跳转路径。两次失败现场的保留尾部都没有
显示候选已经跳到 UEFI、BootShim 或 Linux，也没有出现 `boot.img` 的
kernel handoff 标志。

同一尾部可见 `sec_lk_vb_init() takes 0 ms`、LK/DTB/DTBO 和 modem 的认证通过，
因此这段记录没有出现明确的 vbmeta 验证失败；问题发生在候选镜像进入
`boot_linux_fdt` 之前或 `boot_linux` 事件触发路径上。恢复系统后的当前
Android 状态只说明你已经回刷成功，不改变前两次候选启动失败的现场结论。


## 与正常 `/proc/pl_lk` 对齐后的修正（2026-10-31）

正常启动记录也经过 `starting app fastboot` 与 `wait_for_enter_fastboot`，随后回到 `starting app mt_boot`。因此单独看到 `wait_for_boot_linux` 不能说明候选 boot.img 未加载或被 LK 拒绝。

两边真正可见的分叉：

- 失败 expdb 两次均有 `detect_key:193: home key is pressed`、`boot_reason = 1`、`notify_enter_fastboot`、`wait_for_enter_fastboot`，之后回到 `mt_boot` 并停在 `wait_for_boot_linux:1009`。
- 正常 `/proc/pl_lk` 中按键采样为 `KP_STA: 0x0, KP_MEM1: 0xffff`，`boot_reason = 4`；fastboot 等待后出现 `wait_for_enter_fastboot:130: Ready to enter fastboot...`，紧接 `wait_for_boot_linux:1012: Ready to boot linux...`，之后才加载三个 boot image header，并出现 `boot_linux_fdt` 解压与最终 jump。
- 失败现场中没有 `Ready to boot linux...`、`load_bootinfo_from_hdr` 或任何 `boot_linux_fdt` 标志。

因此当前最强结论是：这两次失败启动均被 LK 记录为 home 键按下并走入 fastboot 事件分支，且没有证据显示 LK 收到了启动 Linux 的事件/命令。它们不能用来证明候选 Android boot header 错误、vbmeta 拒绝、或候选已被 LK 读入后失败。若当时按键确实没有被用户按下，则“LK 检测到 home 键”的来源（实体键/按键电平/残留输入状态）是优先调查项；仅凭 expdb 不能判定该状态如何产生。

这也细化了此前“卡在 wait_for_boot_linux”的说法：该字符串是正常启动共有的事件等待点；区分正常/失败的是正常记录随后有 `Ready to boot linux...` 并进入 image load，而失败记录没有。fastboot 是否由特定 host 命令、按键、或平台事件推进，需结合该会话的实际操作和 fastboot host 日志确认。


## 设备端 strings 后 adb pull（2026-10-31 17:17）

按要求在设备 root 环境执行 `strings -a /dev/block/by-name/expdb`，再用 `adb pull` 拉回：

- `work/evidence-20261031/logs/device-expdb-strings-20261031-1717.txt`
- 1,152,623 字节，SHA-256 `d8426a3abae05f687c5d3a638a5459a63060b7005f9167da84d5f35f7d97dd1c`

这次设备端转换比直接扫描二进制更适合逐行审阅。文件内共有 4 组 `home key is pressed` →
`notify_enter_fastboot` → `starting app fastboot` → `starting app mt_boot` →
`wait_for_boot_linux:1009`；`Ready to boot linux`、`load_bootinfo_from_hdr`、
`boot_linux_fdt`、`booting linux @`、最终 jump 均为 0 次。该新抓取再次确认当前 expdb
保存的失败序列停在 LK 的事件等待分支，没有提供候选 boot header 被接受或跳入
BootShim/UEFI 的证据。当前文件中 `img_auth_required = 0` 和 `avb_ret = 0` 也均为 0，
但这只能说明本次字符串结果没有收录正常 Android 成功片段；不能反推 vbmeta 已失败。


## 最新失败轮次 strings 抓取（2026-10-31 17:27）

最新设备状态为 `ro.boot.slot_suffix=_a`、`ro.boot.bootreason=reboot`、`ro.bootmode=normal`。
设备端重新执行 strings 后拉回：

- `work/evidence-20261031/logs/device-expdb-strings-20261031-172730.txt`
- 1,708,767 字节，SHA-256 `964ac86eaee035f7c84cae922325db2d4b9b9805ed371b6eefebb298575bed71`

这份新文件含有实际 fastboot 写入记录：

- `download:00002000` → `flash:vbmeta_a` → `reboot`
- `download:04000000` → `flash:boot_a` → `reboot`

这和 8 KiB vbmeta、64 MiB AVBf boot 变体的尺寸一致，说明本轮低校验配套至少已经进入 fastboot 的写分区流程。

写入/重启后的 LK 记录仍有 6 组 `home key is pressed`/`boot_reason=1`/`notify_enter_fastboot`，并以
`starting app mt_boot` → `wait_for_boot_linux:1009` 结束；`Ready to boot linux`、
`load_bootinfo_from_hdr`、`boot_linux_fdt`、`booting linux @`、最终 jump 均为 0 次。

因此本轮已经排除了“镜像根本没刷入”的解释，但仍没有测试到 boot.img 解析。当前阻断点是
LK 在重启后继续检测到 home-key/fastboot 状态；这发生在 AVB、Android header、BootShim、
UEFI 之前。`KP_STA=0`/`KP_MEM1=ffff` 仍不能单独说明实体按键来源，需下一轮确保无任何按键
状态后让 LK 离开 fastboot 等待，或取得 fastboot host 的完整操作时序。


## stock LK `detect_key` 反汇编实锤（2026-10-31）

对 `work/evidence-20261031/stock-lk/lk-os3-analysis.elf` 做 ARM64 离线反汇编后，`home key is pressed` 的控制流已经确定：

1. `0xffff00005070dbc4` 一段轮询逻辑分别以 `w0=1` 和 `w0=6` 调用 `0xffff00005072515c`。
2. `0xffff00005072515c` 从 `0xffff0000507e3310` 的 key-code 表取值；当输入 index 为 3 或 6 时，进入 home/power-key 判定分支。
3. 该分支以 `w0=1` 调用 `0xffff000050732d10`。该 helper 通过注册的硬件按键回调读取三组 16-bit 寄存器；回调结果写入栈上的 16-bit 值，随后 `cmp w8,#0; cset w0,eq`，也就是**硬件回调返回 0 时判为按下**。
4. 判定为真后，`0xffff0000507251e0` 传入格式串 `"%s:%d: home key is pressed\n"`，并返回 `w0=1`；上层因此触发 `notify_enter_fastboot`。

这条链在 boot image 读取之前执行。它解释了最新 expdb 中反复出现的 `home key is pressed` → fastboot 等待，也证明当前卡点位于硬件按键/按键驱动状态，早于 AVB、Android header、BootShim 和 UEFI。`KP_STA=0` / `KP_MEM1=0xffff` 是同一现场的按键采样，但仅凭这两个打印值不能单独还原实体按键电平；能确定的是 LK 的硬件回调返回了“pressed”语义。

因此最新 64 MiB AVBf boot 和 8 KiB vbmeta 已经被 fastboot 写入，但重启后没有进入解析 boot.img 的路径。继续改 UEFI 或重做 header 在解除该按键状态前不会改变 expdb 卡点。


## 结论修正：不把 home-key 记录归因到本次 UEFI 失败

用户指出该 LK 按键段与当前 UEFI 故障无关。前文把它提升为本次失败的主因过度推断，现撤回。

保留的事实只有：expdb 历史文本包含 home-key/fastboot 行，且包含若干 fastboot 写分区命令；由于 expdb 是环形历史记录，不能仅凭字符串排列把这些行绑定到同一次候选 UEFI 执行，更不能据此证明当前 UEFI 没有被执行。`lk-homekey-bypass-dryrun.img` 仅是静态控制流实验副本，不是解决方案，也没有刷入设备。

当前工作重点回到 UEFI 固件、BootShim 入口、内存映射、看门狗和 AVBf 容器；新的低校验打包器已经把 AVBf 作为默认输出。下一次可用的运行时判据仍应是同一轮 expdb 中的 `boot_linux_fdt`、BootShim/UEFI marker 或 UEFI 异常记录。
