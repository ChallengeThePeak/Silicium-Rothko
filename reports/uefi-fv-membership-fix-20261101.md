# K70U UEFI：真实 FV 缺少两个驱动，已修复（2026-11-01）

## 已实测与调查方向

新 expdb 已证明 LK 执行了候选加载、header 处理、解压和后续 DTB 回调。
此前“停在 preloader、LK 没加载”的判断是日志归属错误，已写入本项目 AGENTS.md 撤回。
本轮不回到 home-key、恢复后 boot 读回或 NoGZ 猜测，而是检查已交付 UEFI 的实际二进制。

## 源码与二进制实锤

被测试的旧 keepalive boot 是 `01261519293e9ef62756565ccbf94f156a7776145c53edd30858e55e6888bfc6`，
其 FD 为 `2c7e7c5179a6781b2e7f69fa55ea70c9ee5d18835cd151e9e8d4482a5bdd3c42`。

完整解码它的 root FV、LZMA 和内部 FV，并检查 FFS 边界、状态和校验和后发现：

| 模块 | APRIORI 有 GUID | 旧 FD 可执行 FFS | 新 FD 可执行 FFS |
| --- | --- | ---: | ---: |
| RothkoDisplayDxe | 有 | 0 | 1 |
| RothkoWatchdogDxe | 有 | 0 | 1 |

这不是在压缩文件中简单搜索 GUID 得出的结果。旧 FD 的两个 GUID 只出现在 APRIORI
的 RAW 数组；解码 FV 与生成的 `FVMAIN.Fv` 字节一致，`FVMAIN.inf`、`FVMAIN.Fv.txt`
也都没有这两个驱动文件。`Guid.xref` 和编译日志只证明它们编译出来了。

直接原因在旧 `Platforms/Xiaomi/rothkoPkg/Include/DXE.inc:38` 的错误注释及缺项：
它声称只需列在 APRIORI，再列会重复打包，于是没有把两个 INF 放到实际 FDF 文件清单。

两处真实实现进一步确认语义：

- `Mu_Basecore/BaseTools/Source/Python/GenFds/AprioriSection.py:95` 只把 GUID 写成数组；
  到第 119 行生成的是 FREEFORM/RAW 优先级文件，不是驱动可执行文件。
- `Mu_Basecore/MdeModulePkg/Core/Dxe/Dispatcher/Dispatcher.c:1427` 只在已经发现的驱动
  列表里按 GUID 排序，不能通过一个没有 FFS 的 GUID 加载或执行驱动。

**因此，旧 FD 不可能运行这两个缺失的驱动。** 这是确定的 UEFI 封装缺陷，
不依赖本次是否保存了 fault PC。它不证明这就是所有启动问题的唯一原因。

## 最小修复

新源码：`/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed`。

- 修复前检查点：`4630ed3d20933ff6569f5f41f41dbe8ecade5ee0`。
- 修复提交：`544ac2d6980f0d68cc4159bd04c1f24e94c928b3`。
- 只改 `Platforms/Xiaomi/rothkoPkg/Include/DXE.inc`：增加两个 INF，并纠正错误注释。
- APRIORI 顺序不变；两个驱动 C 文件不变；已移除的 600 次喂狗截止保持不变。
- 使用无旧 Build 的独立源码快照、新构建目录；旧源码、FD、boot 全部保留。

新入口 `scripts/audit-rothko-fv.py` 强制验证真实可执行 FFS，不把 APRIORI GUID 当代码。
它对旧 FD 明确失败，对新 FD 通过；校验器的八个正/负向测试也通过，包括缺成员、重复成员、
校验和损坏、截断、隐藏非 padding 尾部及 LZMA 损坏。

`scripts/publish-rothko-uefi.py` 在发布前从最终 boot 解压 FD，再次验证成员与本次 `.efi`
逐字节相同；不是只检查旁边的构建文件。新 FD 的悬空 APRIORI 引用数为 0。

## 新镜像

`D:/漏洞/UNIXNU/适配K70U/bringup/boot-rothko-uefi-fvfix-20261101-avbf.img`

- 大小：67108864 B（64 MiB）。
- SHA-256：`ef6dacb910a7edd646cb68c45c60b014bef4d84996dd95196216bcd42f2953c5`。
- Android boot v4，gzip kernel 为 303034 B（`0x49fba`），空 ramdisk，AVBf digest 核对通过。
- FD SHA-256：`38edb952ea4501f78871ed8454c3d4ce4a8e1c1013dd4f0dd21fa32fdb94ffdc`。
- BootShim 仍与原 stage-coded shim 同字节。
- 最终包内 display PE：`d4f8a0de5ac7eb8ed1502e6e854ddd9a89afb11aaa2bcd8dd8991ad63e3a84a0`。
- 最终包内 watchdog PE：`ba606bbbec00932c5d69c22ee2df208da80d7aa7bb0981767cd6b272a42b9735`。

交付记录：`work/uefi-trace-20261101/fvfix-release.json`。
完整构建与验证：`/home/ubuntu/rothko-evidence-20261101/fv-membership-records`。

## 反编译与其他检查的边界

- 实际被测试的 Sec.efi 已用现有 IDALIB/Hex-Rays 反编译，输入哈希匹配。
  FD 首条分支到 RVA `0xa038`，入口指令与 linked SEC 相符；C 入口字面量正确重定位为 `0x42001050`。
- 独立 TE 重建（含六处 DIR64 重定位）与旧 FD 内实际 SEC TE 字节完全一致。
- x0 跨无栈 cache helper 保存在 x20，随后保存为 gSecEntryArg0，并在 C 入口前设置栈。
  IDA 将 `.text` 当常量可能把其中可写的 gSecEntryArg0 折叠为零，不能把这种伪码误读成 DTB 缺陷。
- GIC/Timer 的地址、PPI、EL1 分支和最终 timer enable 有源码/链接证据支持，本轮不追加盲改。
- 原始 LK framebuffer 地址、大小及 1220×2712 command-mode 几何与当前配置一致。
  末期硬件状态、具体 UEFI 停点仍不由这些静态检查证明。

更多独立记录：`reports/uefi-display-trace-20261101.md`、
`reports/uefi-timer-gic-trace-20261101.md`、`work/uefi-trace-20261101/sec-ida.json`。
REA provider 不可用时使用的是本机直接 IDALIB，未将其伪称为 REA Evidence。

## 尚未实测

新 fvfix 镜像未由代理启动或刷入设备，不能声称已经进入 SEC/DXE、GOP 亮屏或稳定运行。
之前 `0x48552` 的 expdb 只属于旧 keepalive 候选；以后分析新测试要核对 `0x49fba` 和新的用户时间线。
没有新设备记录时，不把旧 dump、PL 初始化寄存器或编译成功替代实机结果。
