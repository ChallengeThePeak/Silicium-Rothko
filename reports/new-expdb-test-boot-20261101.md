# 新 expdb：只分析本轮候选 boot（2026-11-01）

## 范围

按用户给出的顺序：进入 fastboot → 刷新 boot → 启动失败 → 回 fastboot →
刷回原 boot → 原系统第一次失败、第二次成功。
后续原系统两次启动不作为候选成败证据，不转向 NoGZ 或其他因素调查。

## 已实测：完整抓取与数据身份

- 原始分区：`/dev/block/by-name/expdb`。
- 本地完整 raw：`I:/刷机/root/scrcpy-win64-v3.2/k70u-expdb-20261101-1106/expdb.raw.bin`。
- 大小：134217728 B（128 MiB）。
- SHA-256：`dc179bf666686de63883b7370fa2346574a6240cff8f1949bcc3333c9015c12d`。
- 与抓取前手机端 `sha256sum` 完全一致。KernelSU 在 stdout 中增加的 CRLF 已逆转，
  仅在完整大小和哈希都吻合后接受结果；未变换的传输文件 `expdb.bin` 也保留。
- 手机在抓取后断开，未取得可选的第二次设备哈希；不声称做过三方稳定性核对。
- 没有在手机创建临时文件，也没有写分区、刷机、擦除、重启或切槽。

## 已实测：候选记录已单独定位

候选镜像为 `boot-rothko-uefi-keepalive-20261101-avbf.img`，
SHA-256 `01261519293e9ef62756565ccbf94f156a7776145c53edd30858e55e6888bfc6`。
其 Android header 的 kernel_size 是 `0x48552`（296274 B）。

新 expdb 有三处 kernel_size：两处 `0x015141fe` 为已知原系统大小，
只有一处是 `0x00048552`。结合用户时间线，选择这一处候选记录，
不拿原系统记录或恢复后的分区内容替代它。
大小匹配不是刷写内容的密码学证明；镜像身份还依赖用户明确提供的测试顺序。

| 原始 expdb 偏移 | 保留证据 |
| --- | --- |
| `0x7f0f862` | 候选记录前一条 `flash:boot_a` |
| `0x7f0fdaa` | 随后的 `rebooting the device` |
| `0x7f51b0e` | `Ready to boot linux...` |
| `0x7f524ff` | boot header 已加载；随后 vendor_boot/init_boot header 也加载 |
| `0x7f5275c` | `img_auth_required = 0` |
| `0x7f52778` | `avb_ret = 0`，随后继续加载候选；不等于签名认证通过 |
| `0x7f531fc` | `kernel_sz=0x00048552` |
| `0x7f5355b` | `DT overlay ok` |
| `0x7f5357c` | 开始解压 kernel |
| `0x7f535ab` | `decompress_kernel takes 10 ms` |
| `0x7f5363f` | 后续 `io_task_callback fdt=0xffff000047c80000, mode=0` |
| `0x7fbeacc` | 后一条 `flash:boot_a`，按用户时间线为恢复原 boot |

这些是原始文件字节偏移，不是 strings 文件行号。物理相邻片段不是经过验证的整圈启动编号。

独立片段范围为 `0x7f21400` 至 `0x7f55400`（右端不含）：

- 便于阅读且保留逐行原始偏移：
  `I:/刷机/root/scrcpy-win64-v3.2/k70u-expdb-20261101-1106/test-boot-01/candidate-lk.txt`
- 完整片段原字节：同目录 `candidate-lk-fragment.bin`。
- 选择依据：同目录 `selection.json`。
- 相邻刷入/恢复命令分别保存在 `preceding-flash.txt` 与 `following-restore.txt`。
- 失败后的保留复位文字单列在 `after-test-before-restore.txt`，不当作候选内的实时寄存器。

## 不能混淆的故障证据

候选之后、恢复刷写之前的文字里有 `panic_header.exp_type=0`、
`panic_header.wdt_status=0x8004`，并打印过 `TFA_DEBUG_BUF.gz` 保存动作。
但是本 raw 的前 126 MiB 全零，没有 AEE0DEAD 头，也没有任何标准 gzip 头；
这些保存动作所指向的数据区域实际上也是全零。

因此，当前只有 kedump 文字，不存在可验证的 AEE/ATF payload，不能还原本次 PC、ELR、FAR。
19 处 PL 的 `LENGTH=0xFFE0` 也不是 UEFI 的实时阶段信标，不能反推 UEFI 没执行。
独立核对见 `reports/new-capture-aee-20261101.md`。

## 结论与下一步

- **已实测**：本轮新候选对应的 LK 加载/解压记录确实存在，已从原系统记录中单独分出。
- **源码/产物确认**：`0x48552` 与新镜像 header 一致，不是旧 staged 的 296322 B。
- **合理结论**：不能再把本次失败判为 preloader 未加载 LK；AVB 也没有阻断这次候选加载。
- **仍缺证据**：LK 解压和 DTB 回调不是 BootShim/SEC/DXE 执行证明；本次具体停点仍未知。
- **下一步**：若继续修复，应围绕候选 LK 交接后的有效现场取证，不复用旧 AEE，不混入刷回系统后的启动。

本轮只抓取和分析，没有生成另一版镜像或修改固件源码。
