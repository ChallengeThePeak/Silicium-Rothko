# expdb 最新五条逻辑记录

## 输入和分隔方法

- 输入：[device-expdb-strings-20261031-221732.txt](../work/evidence-20261031/logs/device-expdb-strings-20261031-221732.txt)
- 大小：2,013,799 字节
- SHA-256：85749ea53b053516132e622411f49750ea1379f2060cb188693af340378b66af
- 用 strings -a 的行输出做离线分析。
- 在同一份输出中找到 5 个 [SEC] Loading SEC config，按它们分隔出 5 条逻辑启动记录。记录编号按该 strings 文件的出现顺序，行号是该文本文件的行号。

这证明一份 expdb 确实同时保留了最近五条逻辑记录。由于 strings 丢失了二进制边界，下面的行号和事件链是可复核证据；没有出现的字符串不能单独证明对应二进制事件绝对没有发生。

## 五条记录

| 记录 | 行范围 | 关键链 | 结论 |
|---|---:|---|---|
| 1 | 274–7507 | download:04000000 → flash:boot_a → home key is pressed → starting app fastboot → starting app mt_boot → Wait for boot linux event | 没有 Ready、boot header、kernel_sz 或解压标记；停在 LK 等待路径。 |
| 2 | 7508–22568 | Ready to boot linux → 三个 boot header → kernel_sz=0x015141fe → decompress kernel image | 原厂 boot 的完整 LK 解析/解压链；0x015141fe 与当前 boot_a 读回的原厂 LZ4 头一致。 |
| 3 | 22569–28549 | wdt_status=0x8000、panic_header.wdt_status=0x8000、SYS_CUR_PLLK、TFA_DEBUG_BUF.gz、ZAEE_LOG、blackbox boot_index=0, dump_count=3 | AEE/WDT 历史记录；当前 strings 没有可定位 UEFI 的 PC/LR，不能把它直接归因于某个 UEFI 候选。 |
| 4 | 28550–36527 | download:04000000 → flash:boot_a → starting app mt_boot → Wait for boot linux event | 没有 Ready、boot header、kernel_sz 或解压标记；同一条记录的 AEE 状态为 wdt_status=0x2。 |
| 5 | 36528–45139 | download:04000000 → flash:boot_a → home key is pressed → starting app mt_boot → Wait for boot linux event；随后 wdt_status=0x6, exp_type=1、blackbox boot_index=3, dump_count=2 | 仍停在 LK 等待路径；没有进入 boot image 解析。后面的 AEE 是该历史环中的复位记录，不能用缺失字符串定位 UEFI。 |

## 记录 2 的细节

记录 2 同时出现：

- [AVB] img_auth_required = 0
- vbmeta_a: ... HASH_MISMATCH
- load_bootinfo_from_hdr 的 boot、vendor_boot、init_boot 三个 header
- boot_linux_fdt:547: kernel_sz=0x015141fe
- boot_linux_fdt:749: decompress kernel image...

所以这条记录说明低校验策略下，vbmeta 的哈希告警没有阻止 LK 继续解析原厂 boot；它不是 UEFI 候选的失败记录。当前 strings 文件没有 booting linux @ 或 lk finished --> jump 文本，但原厂 Android 已正常起来，最终跳转应以 /proc/pl_lk 的正常链为准。

## 对当前排查的影响

五条记录里，只有第 2 条能证明 LK 走到了 kernel size 和解压阶段。第 1、4、5 条只证明 LK 没有记录到 boot_linux ready 之后的解析链；它们不能证明 UEFI 已经运行，也不能用来选择 GIC、显示或 watchdog 的修复方向。第 3 条是压缩的 AEE/WDT 历史数据，需拿到对应的原始 AEE/TFA 内容后才能定位 PC。

第 1、4、5 条中的 fastboot 文本只证明曾执行过 64 MiB boot_a 写入命令，不能从 expdb 文本反推出实际 payload hash；当前 boot_a 分区读回仍是原厂 LZ4，因此不能把这些写入命令当成当前阶段镜像已经在分区中的证据。
