# K70U UEFI display/GOP 独立核对（2026-11-01）

## 绑定与范围

- 只读核对已交付候选 `boot-rothko-uefi-keepalive-20261101-avbf.img` 的显示/GOP 合同。
- 源码：`/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean`，提交 `0b5a75c6716108d4458470938c265b186da7a07e`。
- 使用本次候选 LK 片段，不借用恢复原系统后的状态，不操作设备或重编固件。
- 主代理维护共享计划；本工作证据目录是 `keepalive-clean-records/uefi-display-trace-01`。

## 主要发现：显示与硬件喂狗驱动没有装入原候选 FD

**已通过完整 FV 解码确认，不是字符串缺失推断：原候选只有两个驱动的 APRIORI GUID 引用，
没有它们的可执行 FFS 文件。**

证据闭环：

1. 输入 FD SHA-256 为 `2c7e7c5179a6781b2e7f69fa55ea70c9ee5d18835cd151e9e8d4482a5bdd3c42`。
   外层 FV、LZMA 内层 FV 的长度、header checksum、FFS header checksum、全部 section bounds 均通过。
   共解析 32 个 FFS（含外层与 padding），87 个 section，没有未解析的压缩容器。
2. 解压后的 FV SHA-256 为 `da34a8167296f048f16bd4cec147a6a8c85d2e482d70ff16c2699901a584ee05`，
   与构建目录 `FVMAIN.Fv` 逐字节一致，排除了“只扫描了错误层”的可能。
3. `RothkoDisplayDxe` GUID `D6A1F3C8-2B47-4E19-9F52-7C3A8D1B6E04` 和
   `RothkoWatchdogDxe` GUID `79BCE177-C3F4-4F57-AED9-C0B2BD5B9A31` 的可执行 FFS 数都为 **0**。
   两个 GUID 在内层 FV 中分别只出现在 `0x1e4` 与 `0x124`，均处于 APRIORI RAW GUID 数组。
4. `FVMAIN.Fv.txt` / `FVMAIN.inf` 的文件清单也缺这两个驱动。
   `Guid.xref` 中有名字只证明构建知道模块，并不证明模块被放入 FD。
5. 源码 `Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc:29`、`:54` 仅列了优先顺序。
   `Include/DXE.inc` 没有相应 INF；`:38` 至 `:42` 的旧注释声称再写 INF 会重复打包，这是错误认识。
6. BaseTools `Mu_Basecore/BaseTools/Source/Python/GenFds/AprioriSection.py:95` 至 `:119`
   明确只把各 INF 的 GUID 写入 RAW section，再创建一个 FREEFORM APRIORI FFS；不会把驱动 PE 放进 FV。

这是一项确定的 UEFI 封装阻塞：即便 SEC/DXE 正常运行，原镜像也没有可分发的 Rothko GOP
驱动和独立硬件喂狗驱动。此前修改它们的源码、检查 `.efi` 或观察构建日志，均不足以证明修改进入启动镜像。
它不证明当前设备已经执行到 DXE，也不能据此复原缺失的本次 PC。

## 修复后镜像的独立核对

主代理在新目录 `Mu-Silicium-fv-membership-fixed` 修复 `Include/DXE.inc:24`、`:25`，
加入两个实际 INF，保留 APRIORI 的顺序引用。
源码提交：`544ac2d6980f0d68cc4159bd04c1f24e94c928b3`。

新 FD SHA-256：`38edb952ea4501f78871ed8454c3d4ce4a8e1c1013dd4f0dd21fa32fdb94ffdc`。

| 检查项 | 原 FD | 修复后 FD |
| --- | --- | --- |
| Display APRIORI 引用 | 有 | 有 |
| Display 可执行 FFS | 0 | 1 |
| Watchdog APRIORI 引用 | 有 | 有 |
| Watchdog 可执行 FFS | 0 | 1 |
| dangling APRIORI 引用 | 2 | 0 |
| 对应 flat `.efi` 的完整字节匹配 | 无可比较的 payload | 两者都一致 |

新内嵌 PE 哈希：

- Display：`d4f8a0de5ac7eb8ed1502e6e854ddd9a89afb11aaa2bcd8dd8991ad63e3a84a0`。
- Watchdog：`ba606bbbec00932c5d69c22ee2df208da80d7aa7bb0981767cd6b272a42b9735`。

这次证明的是 **可执行代码真正存在于最终 FD 的 FFS 中**，不是仅列在顺序表里。
设备运行、面板推帧和 IRQ 交付仍需与离线封装证明分开。

主代理最终发布并重新回拆核对的 boot：

- 路径：`D:/漏洞/UNIXNU/适配K70U/bringup/boot-rothko-uefi-fvfix-20261101-avbf.img`。
- SHA-256：`ef6dacb910a7edd646cb68c45c60b014bef4d84996dd95196216bcd42f2953c5`。
- gzip kernel：303034 B（`0x49fba`），与原候选 `0x48552` 区分。
- 发布清单：`work/uefi-trace-20261101/fvfix-release.json`。
- 主代理对实际 boot 回拆得到 FD `38edb952...`，再调用同一固定哈希的 FV checker，
  两个内嵌 PE 与新构建 flat `.efi` 完整匹配；这不是只校验 Build 目录里的 FD。

## 固化的验收工具

新增 `scripts/audit-rothko-fv.py`，可调用 `audit_firmware(fd_bytes, efi_dir=...)`，或：

```text
python3 scripts/audit-rothko-fv.py <FD> --efi-dir <AARCH64输出目录> --output <全新证据目录>
```

- 必须找到两项唯一、active、AArch64 DRIVER FFS；单独的 APRIORI GUID 不能算模块。
- 区分 executable inventory、APRIORI references 和 dangling references。
- 完整验证已支持的 FV/FFS/section 边界与 checksum，限制解压大小，拒绝不完整解析。
- 指定 flat 目录时逐字节比较实际 PE payload；不静默吞掉重定位/格式转换差异。
- 原 FD 以退出码 1 正确失败；新 FD 退出码 0。
- 8 项回归全部通过：原 FD 缺模块、真实 FFS 正向样本、只含一个模块、重复模块、
  FV checksum 损坏、截断、尾部藏非 padding 数据、LZMA 内容损坏。
- 第一轮 LZMA 损坏 fixture 误用了全文件第一个 GUID（SEC 内也含解码器 GUID）；
  已改为从解析出的 GUID section 定位数据，保留了首轮失败结果，没有把它伪装成产品失败。

工具 SHA-256：`6b644b5dadb9ef8a79b82fd5af7fcc11cc5ed86ca24fad8ac158a725ae2335b2`。

## SEC 平面 PE 与 FD 内 TE 的绑定

- **本节仅绑定原测试 FD `2c7e7c51...` 和 `Mu-Silicium-keepalive-clean` 的 flat SEC**，
  不把这个归一化结果冒充修复后 FD 的独立 SEC 分析。
- FD 内 SEC 是 TE，不是 flat `Sec.efi` 的直接字节副本。
- TE 位于 FD `0x158`，StrippedSize=384，TE header=40 B，ImageBase=`0x42000000`，entry RVA=`0xa038`。
- 从 flat PE 的真实 `.reloc` 读出 6 个 DIR64 relocation，加上 image base，去除 PE headers 和
  尾部 `.reloc` payload，清空其 section size 并生成 TE header 后，得到与 FD 内 TE **完全一致**的字节。
- TE SHA-256：`dd24d5bdf30d94aa39631b8c90e1176b0671922bbed6d441d628aaf6610ef3fe`。
- FD 首条 AArch64 B 指令的目标偏移也为 `0xa038`，与 TE entry 一致。
- 详情在 `sec-te-normalization.json`；这是静态身份和重定位证明，不是 SEC 实机执行证明。

## 已实测的输入与源码确认

1. 本次候选 LK 日志第 3515/3516 行（raw `0x7f43120` / `0x7f431bc`）明确记录
   framebuffer 地址 `0xfd91f000`、大小 `0x26e0000`。
2. 当前 `MemoryMapLib.c:18`、`:19`、`:46` 映射完全一致；当前显示驱动缺属性时的 fallback 也一致。
   本次不能归因于 framebuffer 高位、物理 RAM 配置或 framebuffer carveout 地址不匹配。
3. 当前 `mMutexBanks` 与 memory map 都没有 `0x14020000`；不能套用旧版“访问未映射此地址”的结论。

4. 本次 LK 的 `DSI_tx_buf_rw`（raw `0x7f42f6a`）给出 mode=0、width=1220、height=2712；
   面板名为 `n12_42_02_0a_dsc_cmd_lcm_drv`。与当前几何和 command-mode gate 一致。
5. 原树实际编出的模块 `Build/rothkoPkg/DEBUG_CLANGPDB/AARCH64/RothkoDisplayDxe.efi` 的 SHA-256 为
   `f3e26075e5d39b74a83ab76e5f0d66b565d562a6c2222912a56eff4a380ef563`。
   `Refresh` 的 map RVA 为 `0x23dc`，实际反汇编包含活动/dirty 判断、镜像复制、mutex enable、
   DSI busy 检查与 `DSI_START=0 -> 1`。但如主要发现所示，该 flat PE 并未放入原 FD。

## 必须满足、但本次没有实时寄存器证明的门槛

- `ReadDeviceTree` 验证入口 HOB、DTB 对齐与映射范围、完整 FDT header、chosen cells；
  `EFI_NOT_FOUND` 可用已知 framebuffer fallback，`EFI_INVALID_PARAMETER` 则直接返回。
- `LayerIsLinear` / `CollectScanout` 只接受 full-screen 1220x2712、packed 32bpp、
  pitch 4 字节对齐、落在 carveout 内的线性层，不接受压缩、旋转、裁剪或额外格式状态。
- `ProbeScanouts` 最终必须找到地址恰好为 `mFbBase` 的层；否则 `StartRefresh` 禁止推帧。
- `ProbeMutex` 要求唯一的 single-mode group，含 DISPSYS1 DSI0 位和 OVLSYS overlay 位；
  没找到或多组匹配都只返回错误，不猜测路由。
- `StartRefresh` 只接受 DSI command mode；GOP 成功后推帧失败仍允许 BDS 继续。
- `ROTHKO_HALT` 当前是日志宏，不是历史版本的死循环。正常配置 heartbeat/liveness 也均为 0。
  不能把注释中的旧死循环描述当成当前代码行为。

## 不能直接当作故障修复的疑点

- `Refresh` 先镜像 buffer 并 enable mutex，之后 `PushFrame` 才读取 DSI busy。
  实际反汇编在 RVA `0x24f8` 写 mutex，在 `0x2510` 读 DSI 状态，`0x2514` 按 busy 返回。
  这是可复核的顺序；可能产生 in-flight 更新风险，但当前无 busy/路由现场，不能说它就是本次黑屏根因。
- 提交代码完全依赖 LK 留下的 DSI/DSC/时钟/命令队列设置，只写 start 和 mutex。
  LK 初始化阶段日志正常不证明最终交接时硬件状态仍相同，需要最终 uninit/交接代码或对应实时寄存器补证。

## 边界

本次日志已证明 LK 加载候选，但尚无 BootShim/SEC/DXE 实机执行证明。
显示代码的正确性、早退条件或缺陷都不能自动当成本次实际故障点。
