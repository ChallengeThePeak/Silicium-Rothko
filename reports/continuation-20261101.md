# K70U UEFI 继续修复记录（2026-11-01）

> 后续 FV 审计更正：本文记录的 keepalive 驱动确实重编了，但 display/watchdog 的
> 可执行 FFS 均未进入那份 FD。不能把本文的模块反汇编或主机测试当作已交付驱动的执行证明。
> 已另行修复 FDF 缺项并从最终 boot 验证，最新结论见 `uefi-fv-membership-fix-20261101.md`。

## 已实测：离线日志和文件核对

- 用户明确说候选启动失败后刷回系统，再提取 expdb；恢复后的 stock boot 不能否定之前的候选测试。
- 本次输入 `I:/刷机/root/scrcpy-win64-v3.2/expdb.strings` 为 575643 B、13487 行。
  SHA-256：`ef6068d5d146bd23cabef1c0196c8023c403da89de721f95dc5f272ca06fff23`。
- 第一条保留的 `flash:boot_a` 在 5422 行，`rebooting the device` 在 5547 行。
  紧接的文本已单独保存为 `work/evidence-20261101-continuation/expdb-analysis-01/flash-01-adjacent-text.txt`。
  对应原文件 5548–6364 行，包含此前漏掉的两行 early-save 信息。
- 第 6361 行是 `Init Boot Device: OK(0)`，随后是日志保存；没有在此记录 CPU 异常。
- 6365–7177 与 7178–7990 的 813 行前缀逐字节相同，SHA-256 为
  `1111fafde83e1bbc18ca048b0b40db274d7ca00f0ad98f8d4f1a4db4b6a8adf5`。
  后一份副本继续进入 LK，不能把前一份副本的末尾当作 CPU 停止位置。
- 正常对照 `work/evidence-20261031/logs/proc-pl_lk-normal-20261031.txt` 的 689/690 行也有
  `#T#WDT_INIT=2` 和 `RAM_CONSOLE wdt status 0x800`，随后 4216 行 Ready、4282 行加载 stock kernel。
  因而这两项不能作为 preloader 故障证据。

**撤回上个聊天“第一次失败停在 preloader/BL2、尚未进入 LK”的确定性结论。**
正确说法是：保留到了早期 PL 日志，但这份 strings 没有完整的本次执行停点证据。
文件物理顺序、保存片段、实际启动顺序不是同一回事。

## 源码确认：交付来源和喂狗限制

- confirmed 与 stage-coded 两个 boot 镜像同为 64 MiB，SHA-256 完全相同：
  `18eced1a56c33b9b34d35d037cb2f8b97832f6bf704638d1cd28fa9cc7b78a16`。
- 解压 FD 均为 `d55a4f9d5cb5a85475c810f8b4824ac50a0c723486e667ee867650b30a847948`。
- staged 的 `RothkoWatchdogDxe.c:33` 含 `++mDiagnosticTicks < 600`，回调为 100 ms。
  `RothkoWatchdogDxe.efi` 实际反汇编也含计数比较；不是只存在于旧源码的死代码。
- 较新的 confirmed 源码目录有额外 MODE.EN 清零和 NONRST 覆盖，但模块和 FD 仍是旧哈希，不能说已重编。
  本轮不采用这些没有充分硬件依据的寄存器修改。
- 旧 `build-staged-01/result.json` 记录 FD 哈希 `2b7d55f8...`，与交付的 `d55a4f9d...` 不同。
  同一 Build 目录的后续重编没有同步该 manifest，因此仅凭旧 result.json 不能复现交付状态。
- AEE23 的 FAR 信标只有低 24 位；假设完整 FAR=-15 才可推出 Buffer=9。
  防御性 pool 检查不能证明原始坏指针来源已修复，不能拼接不同启动的 FAR 位段当作同一次完整现场。

## 本轮改动与验收

1. 新增 `scripts/analyze-expdb-strings.py`，只输出“保留片段”和文本邻接关系，不伪造启动编号或故障阶段。
2. 新增 `scripts/test-expdb-strings.py`；10 个内存内测试全部通过。
3. 已在新的 WSL ext4 源码/构建目录中，仅移除正常 watchdog 回调的 600 次截止。
   旧树保留，MODE/NONRST 不变；BootShim 与上一版同字节。
4. 主机测试直接编译实际驱动源码，GCC 13.3 + ASan/UBSan：新驱动 7/7 通过。
   10,000 次回调加入口调用共 10,001 次 RESTART 写入；旧驱动负向对照只有 599 次。
   inactive、ExitBootServices 停止以及四条初始化失败路径均通过；无 sanitizer 错误。
5. 新的 build-01 从不存在旧 Build 的源码快照构建，返回 0，耗时 34 秒。
   新 `KickWatchdog` 反汇编只有 active 判断，不再读取/递增诊断计数器。
   保留一个既有的 HwResetSystemLib library-class warning，不宣称零告警。

## 新交付镜像

`D:/漏洞/UNIXNU/适配K70U/bringup/boot-rothko-uefi-keepalive-20261101-avbf.img`

- 大小：67,108,864 B（64 MiB）。
- SHA-256：`01261519293e9ef62756565ccbf94f156a7776145c53edd30858e55e6888bfc6`。
- Android boot v4，空 ramdisk，gzip kernel 296274 B，AVBf digest 核对通过。
- BootShim 256 B，保持原 x0/DTB 传递与阶段标记，不是 entry-only park probe。
- FD 2 MiB，SHA-256：`2c7e7c5179a6781b2e7f69fa55ea70c9ee5d18835cd151e9e8d4482a5bdd3c42`。
- watchdog 模块 SHA-256：`96d40e5be3c98a559dfc66148d45610fcb5bd534ec967fe68e915a332427ed32`。
- 源码修复提交：`0b5a75c6716108d4458470938c265b186da7a07e`。
- 封装回拆与新 FD、Shim 逐字节相符，发布到 D: 后的副本哈希也相符。
- 本轮没有制作或修改 vbmeta、preloader、LK、TEE 等其他分区镜像。

机器可读记录：`work/evidence-20261101-continuation/keepalive-release.json`。
它关联源码补丁、构建输入、真正的 build result、驱动反汇编、正/负向测试和最终镜像。

## 可复现路径

- 新源码：`/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean`。
- 完整来源清单与构建记录：`/home/ubuntu/rothko-evidence-20261101/keepalive-clean-records`。
- 来源清单含 44502 个文件/链接；旧 Build 与 Git 数据没有复制进新源码。
- 构建入口：`scripts/build-rothko-evidence.py --build-id rothko-keepalive-20261101 --require-clean-source`。
  必须另给新的源码快照和新的 `--output`，不能复用已完成的 Build。
- 驱动测试：`scripts/test-rothko-watchdog-host.py --source <实际驱动.c> --output <新的ext4目录>`。
- 补丁：`work/evidence-20261101-continuation/watchdog-keepalive.patch`。
- 发布核对入口：`scripts/audit-rothko-keepalive.py`；拒绝覆盖已有镜像或审计记录。
- 本地证据提交：`38e2ac116a3bcb9a1a1f0ed44ed82b4ba27efbb1`，在独立的
  `keepalive-clean-records` 仓库保存来源清单、构建日志、正/负向测试及 20 个项目文件快照。
  没有提交或改动父仓库里无关的 yunluo 工作；不是伪造上游历史。
- 提交与镜像对应关系：`work/evidence-20261101-continuation/version-checkpoints.json`。

## 合理推断、阻塞与下一步

- 去掉诊断截止可避免计时回调正常运行时人为停止喂狗；它不是当前早期黑屏的已证实根因。
- 当前 strings 未保留可验证的本次 AEE 容器、ATF PC 或 UEFI 阶段值，不能恢复缺失的现场。
- 本轮已完成这项离线源码修正和可追溯重编；未操作设备，不声称真机已进入 UEFI。
- 本次早期不开机的实际故障点仍未确定。后续若要做实机归因，需要同次尝试的有效 AEE/原始日志容器；
  不能用当前 strings 的最后一行代替，也不应为此直接修改 preloader/LK。
- D: 空间紧张，源码、对象和完整清单放在 Ubuntu2404 ext4，仅交付一个新 boot 和小型记录。
