# AGENTS.md - K70U UEFI 当前交接结论

本文件只记录 K70U 项目事实与调查方向。全机环境、WSL 构建方式和安全约束继续继承
父目录 `../AGENTS.md`、`../CLAUDE.md` 及用户提供的全机规则；不在此另建环境配置副本。

## 2026-11-01：已实锤 LK 执行并加载本轮候选

**本轮已经有实机日志证明：LK 执行了新候选 boot 的加载链。之前把故障判在
preloader/BL2、认为没有进入 LK 的结论，是日志读取和归属判断错误，明确撤回。**

之前的错误包括：把 early_save_pllog 的保存片段末尾当成 CPU 停点；把环形日志物理
顺序当成完整启动顺序；用刷回原系统后的 boot 读回结果否定更早的候选测试。
以后不得重复这些判断方式，也不得仅凭缺少 LK/UEFI 字符串推断代码没有执行。

### 当前证据

- 完整 expdb：`I:/刷机/root/scrcpy-win64-v3.2/k70u-expdb-20261101-1106/expdb.raw.bin`。
- raw 为 134217728 B，SHA-256：
  `dc179bf666686de63883b7370fa2346574a6240cff8f1949bcc3333c9015c12d`，与设备端抓取前哈希一致。
- 候选：`bringup/boot-rothko-uefi-keepalive-20261101-avbf.img`，SHA-256：
  `01261519293e9ef62756565ccbf94f156a7776145c53edd30858e55e6888bfc6`。
- `0x7f531fc` 的 `kernel_sz=0x00048552` 与本候选 296274 B gzip 完全对应；
  另外两处原系统大小 `0x015141fe` 不作为本轮候选证据。
- 同段包含 Ready、boot/vendor_boot/init_boot header 加载、`img_auth_required=0`、
  `avb_ret=0`、DT overlay、解压耗时 10 ms，以及后续 DTB 回调。
- 独立测试段：
  `I:/刷机/root/scrcpy-win64-v3.2/k70u-expdb-20261101-1106/test-boot-01/candidate-lk.txt`。
- 详细依据：`reports/new-expdb-test-boot-20261101.md`；证据提交 `48483749e722b1b06c69d87b81f324085d614ddc`。

### 不得扩大结论

- LK 加载记录不等于已实测执行 BootShim、SEC、DXE 或显示正常。
- 本次 raw 没有完整 AEE/ATF payload，不能恢复本次 PC/ELR/FAR；`TFA_DEBUG_BUF.gz`
  保存动作的文字不是实际 dump。不得拿旧启动的 AEE 拼成本次现场。
- `avb_ret=0` 且继续加载不等于密码学签名认证通过。
- 用户的顺序是候选失败后回 fastboot 刷回原 boot，原系统随后失败一次、第二次成功。
  后两次不混入候选判断。用户要求不转向 NoGZ 或其他因素调查。

## 接下来只向 UEFI 侧推进

从已确认的 LK 加载链继续检查最终交接、BootShim 搬移/缓存发布、SEC 入口与栈、
异常级别、MMU/HOB、GIC/Timer 和 DXE。以实际镜像、反编译/反汇编、源码和匹配记录
交叉核对；每个结论标明“实测 / 源码或二进制确认 / 条件推导 / 未知”。
没有新的正向证据，不再回到 home-key、boot 未刷入、preloader 未加载 LK 等已撤回方向。

## UEFI 侧已确认的封装缺陷

对已测试 keepalive 候选的实际 FD 解压并完整遍历后，确认：
`RothkoDisplayDxe` 和 `RothkoWatchdogDxe` 虽然编译出来、也列在 APRIORI 中，
却没有各自的可执行 FFS 文件。生成的 `FVMAIN.inf` / `FVMAIN.Fv.txt` 也缺少这两个文件。

原因是 `Platforms/Xiaomi/rothkoPkg/Include/DXE.inc` 漏列两个 INF，并含有错误注释，
声称“只列 APRIORI，再列会重复打包”。实际 BaseTools 的 APRIORI 生成器只写 GUID
顺序数组；DXE dispatcher 只能从已发现的真实 FFS 中选择驱动，不能凭 GUID 生成代码。

这是源码、生成清单、最终 FD 三方面一致的确定缺陷，不是通过缺失运行日志猜测。
后续必须同时检查最终 FV 中真实可执行成员、APRIORI 引用、打包模块与编译模块的字节一致性。
不得再用 `.efi` 存在、`Guid.xref` 有名字或 build report 有模块名作为“已入包”证明。
补入 FFS 解决的是确定的封装问题，仍不等于新固件已经实机进入 DXE/GOP。

已实测过 LK 加载的旧 keepalive 候选源码：
`/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean`，
修复提交 `0b5a75c6716108d4458470938c265b186da7a07e`。
配套记录：`/home/ubuntu/rothko-evidence-20261101/keepalive-clean-records`。

最新离线 fvfix 修复源码：
`/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed`，
提交 `544ac2d6980f0d68cc4159bd04c1f24e94c928b3`。
新镜像 `bringup/boot-rothko-uefi-fvfix-20261101-avbf.img`，SHA-256：
`ef6dacb910a7edd646cb68c45c60b014bef4d84996dd95196216bcd42f2953c5`。
其 kernel_size 为 `0x49fba`，已从最终 boot 回拆验证两个真实驱动各一份、代码字节一致、
悬空 APRIORI 引用为零；**尚未取得能绑定此候选的运行阶段证据**。旧 expdb 的 `0x48552` 不得当成新版测试结果。
完整说明：`reports/uefi-fv-membership-fix-20261101.md`。

后续输入 `C:/Users/Administrator/Pictures/expdBUEFIBX` 为 640127 B 纯文本，缺少
kernel_size 和有效异常现场，不能据此确认新版停点或否定已经实锤的 LK 加载链。
它不等于完整 raw；具体边界见 `reports/expdBUEFIBX-20261101.md`。

再次构建必须使用新快照/新输出，不覆盖现有 Build 或镜像；不得将旧 FD 换名后称为新构建。

本轮继续反编译不授权刷写、擦除、重启或改变设备；设备操作仍须用户明确授权。

## 工作区版本库与自动备份（2026-11-02 建立）

- 本目录（`D:/漏洞/UNIXNU/适配K70U`）现为**独立 git 仓库**（`main` 分支），
  嵌套在父仓库 `D:/漏洞/UNIXNU` 之内；提交本目录时不要影响父仓库。
- `.gitignore` 排除了大体积可再生产物：`src/`（2.2 GB EDK2 源码树）、`work/`（3.0 GB）、
  `bringup/`（342 MB 镜像）、`logs/`、`_quarantine/`，以及 `*.img`、`*.fd`、`*.bin`、
  `*.raw`、`*.zip`、`*.gz` 等二进制。入库的是文档、脚本、规划与记忆：
  `AGENTS.md`、`reports/`、`scripts/`、`.planning/`、`.workbuddy/`。
- 自动备份：`scripts/auto-backup.sh` 执行 `git add -A` 后提交（提交信息 `auto: <时间戳>`），
  无改动直接跳过、不产生空提交；执行记录写在 `.git/auto-backup.log`（保留最后 200 行）。
- **不要创建定时任务/自动化**：备份按需手动执行 `bash scripts/auto-backup.sh`，或由当前会话临时调用。
  只做本地提交，**不做 `git push`**，也不删除任何文件。
- 需要备份镜像或源码树时，不要改 `.gitignore` 往里塞二进制；用外部盘或
  `_quarantine/` 归档，并在报告里记录哈希。

## 交付格式约定（2026-11-02，用户指定）

每次给出可刷写产物时，**固定交付两个镜像**，缺一不可：

- `bringup/boot-k70u-uefi-<标签>-<YYYYMMDD>.img`
- `bringup/init_boot-k70u-uefi-<标签>-<YYYYMMDD>.img`

刷写指令固定三行，**必须带镜像绝对路径**，**不写 adb/fastboot 的可执行文件路径**（直接 `adb` / `fastboot`），
并包含自动重启：

```
fastboot flash boot "D:\漏洞\UNIXNU\适配K70U\bringup\boot-k70u-uefi-<标签>-<日期>.img"
fastboot flash init_boot "D:\漏洞\UNIXNU\适配K70U\bringup\init_boot-k70u-uefi-<标签>-<日期>.img"
fastboot reboot
```

同时给出两个镜像的 SHA-256，便于刷前核对。不要只给 boot，也不要把 adb 路徑写进命令行。

## 检索工具（强制，2026-11-02）

搜文件内容一律用 `rg`（ripgrep），**禁止 `grep` / `grep -r` 递归扫目录**；按文件名找用
`rg --files` 或 Glob，不要全盘 `find`。WSL 内 `rg` 在 `/home/ubuntu/bin/rg`。
