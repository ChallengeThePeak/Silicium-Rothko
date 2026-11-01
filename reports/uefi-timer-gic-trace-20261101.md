# K70U UEFI GIC / Timer：源码与链接产物审计

## 结论与范围

**本轮没有找到已经闭合到当前失败现场、足以支持修改 GIC/Timer 的确定错误。** 标准 GIC 地址、物理 timer INTID、异常级别访问分支、最终解除 timer mask 的动作均能在源码与实际链接产物之间核对。

这不等于真机中断或 DXE timer 已通过。主分析另行发现并处理 FD 成员缺失问题；本报告不把“存在编译输出”当成“已打入 FD”，更不当成设备已经执行。没有修改任何 GIC/Timer 源码，没有运行设备或重新构建固件。

## 输入身份

- 源码：`/home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean`
- 审计时 HEAD：`0b5a75c6716108d4458470938c265b186da7a07e`，tracked 工作区干净。
- 对应 FD SHA-256：`2c7e7c5179a6781b2e7f69fa55ea70c9ee5d18835cd151e9e8d4482a5bdd3c42`。
- `ArmGicDxe.efi`：`7141d365f8f92cd1109f5776f63b00019c34d49ec6d60649bea618662bb1867b`。
- `ArmTimerDxe.efi`：`703770c5071147372889f01e32c5a6562eb5203d3d1400e45a62c80db907f2dd`。其 BASE_NAME 是 ArmTimerDxe，不是 TimerDxe。
- 原厂 DTB：`D:\漏洞\UNIXNU\适配K70U\work\extracted\vendor_boot_dtb0.dtb`，SHA-256 `824d63e438703659367e9598dca6b05abdf95a74c1cb778bd298ded9075e34b2`。

下文二进制地址均为对应 UEFI 模块的 RVA，不是本次设备 PC。

## GIC 地址、亲和性和步长

原厂 `/interrupt-controller@c400000/reg` 实际读取结果：

```text
0 c400000 0 40000 0 c440000 0 200000
```

源码 `Silicon/MediaTek/MT6989Pkg/MT6989Pkg.dsc.inc:42`、`:43` 及实际 AutoGen.h 一致使用 GICD `0x0c400000`、GICR `0x0c440000`。链接后的 ArmGicDxe 在 RVA `0x1284`、`0x12b8` 装载对应常量。

`Mu_Basecore/ArmPkg/Drivers/ArmGicDxe/GicV3/ArmGicV3Dxe.c:59` 起将 MPIDR Aff0/1/2 与 Aff3 正确拼成 GICR_TYPER 亲和性格式；`:69` 起检查 2 MiB 窗口边界，`:97` 读取 TYPER，`:109` 按每个 frame 的 VLPIS 位选择步长。

实际链接结果：

- RVA `0x12ac`、`0x12b0`、`0x12c4`：提取并组合 MPIDR affinity。
- RVA `0x12c8`、`0x12cc`：分别装载 `0x20000` 和 `0x40000` 步长。
- RVA `0x12d0` 起：窗口界限判断；没有无界扫描到任意 MMIO。
- RVA `0x1300`：比较 GICR_TYPER 高 32 位的 affinity。
- RVA `0x1308`、`0x130c`：按 VLPIS 选择步长；`:0x1314` 检查 LAST 位。

原厂节点没有 `redistributor-stride` 属性；未找到一个与该标准步长逻辑矛盾的 DTB 覆盖值。

## Timer INTID、寄存器与 unmask

原厂 `/timer/interrupts`：

```text
1 d 4 0 1 e 4 0 1 b 4 0 1 a 4 0
```

这是 secure physical 29、non-secure physical 30、virtual 27、hypervisor 26；clock-frequency 声明为 13000000。当前生成的 TimerDxe AutoGen.h 同样给出 29/30/27/26，PcdTimerPeriod 为 100000 个 100 ns 单位。

`Silicon/MediaTek/MT6989Pkg/MT6989Pkg.dsc.inc:17` 选择 physical timer；`Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc:140` 链接 ArmGenericTimerPhyCounterLib。该库使用 CNTPCT、CNTP_CTL 和 CNTP_CVAL，读取 CNTFRQ，不在初始化中把频率改成其他硬编码值。

源码与链接产物核对：

- `Mu_Basecore/ArmPkg/Drivers/TimerDxe/TimerDxe.c:404` 至 `:419` 注册各 timer INTID；ArmTimerDxe RVA `0x11e4` 起分别装载 30/29/27/26。
- 同文件 `:381` 起先 mask、disable；`:436` 至 `:438` 最终写入 `ARM_ARCH_TIMER_ENABLE`，**没有把 IMASK 留置为 1**。
- 二进制 RVA `0x1360` 装载 1，`0x1364` 调用控制寄存器写入函数，证实最终 unmask 动作已链接。
- `Mu_Basecore/MdePkg/Library/ArmLib/AArch64/AArch64ArchTimerSupport.S:24` 的访问器先检查 CurrentEL。ArmTimerDxe RVA `0x2fac` 的 EL1 分支跳过 HCR_EL2，读取 `CNTP_CTL_EL0`；RVA `0x3260` 的写路径同理。只有 EL2+VHE 分支使用 EL02 别名。
- `TimerDriverSetTimerPeriod` RVA `0x14ec`，中断 handler RVA `0x15bc`，重装 CVAL 的循环 RVA `0x1644`；没有发现当前非零默认周期与物理 timer 选择之间的矛盾。

因此本轮不支持“PPI 号码错了”“EL1 无条件访问 EL2 timer 寄存器”或“初始化忘记清除 IMASK”这些判断。

## CPU 中断使能不是永久 shadow

GIC 的 SRE helper 并非在 EL1 硬读 ICC_SRE_EL2：

- `Mu_Basecore/ArmPkg/Drivers/ArmGicDxe/GicV3/AArch64/ArmGicV3.S:34` 起依据 CurrentEL 选择 ICC_SRE_EL1/EL2。
- 实际 ArmGicDxe RVA `0x49b8` 起含同样分支；EL1 的读取在 `0x49d0`。
- CPU interface 在 RVA `0x499c` 起写 `ICC_IGRPEN1_EL1=1`；使用 IAR1/EOIR1 的 Group 1 路径。

`Mu_Basecore/ArmPkg/Drivers/CpuDxe/CpuDxe.c:371` 的 HardwareInterruptProtocolNotify，在 GIC 安装硬件中断协议后，将 shadow 函数换成真实 enable/disable/state 函数（`:391` 起）；`:395` 按已记录状态恢复中断。通知注册在 `:488`。

`Mu_Basecore/MdeModulePkg/Core/Dxe/Event/Tpl.c:146` 在恢复到 TPL_HIGH_LEVEL 以下时调用真实 EnableInterrupt。ArmLib 的实际动作是 `msr daifclr`。这些是源码/链接链路确认，不是本次手机上已经投递过 IRQ 的证明。

## LK 最终 quiesce 的限定追踪

使用已有、与 IDA 导出 input SHA 一致的 `lk-os3-analysis.elf`：

```text
SHA-256 301eda662bf6c84050cce175b03e6d97691327f49c2cdd0a337563e3eec6438d
PT_LOAD file+0x1000 -> VA 0xffff000050700000
```

已确认的直接路径：

1. 保存的 boot_linux_fdt 反编译末尾进入 `0xffff00005071a7c0`。
2. `0xffff00005071a7d4` 执行 `msr daifset,#2`；`0xffff00005071a7f0` 调用 `0xffff000050703914`。
3. 此函数调用 `0xffff000050712700`；该叶函数完整内容是清零 CNTP_CTL_EL0、ISB、RET。**这是停止物理 timer，不是设置 GICR_WAKER**。UEFI 的后续 TimerInitialize 会重新配置并 enable 同一物理 timer。
4. 同层 `0xffff00005073f340` / `0xffff00005073f328` 分别设置 WDT LENGTH、写 RESTART；`0xffff0000507744c0` 由其引用的 `aee_lk`、`vm_mblock_reserved_info`、`mrdump_save_reserved_info` 字符串及数据复制流识别为 reserved-info 保存逻辑。
5. 尾部 `0xffff000050703948` 含对 `0xffff000050777c28 -> 0xffff000050795220`、`0xffff000050777c24 -> 0xffff000050783bc0` 的调用，以及 `devapc_protection_enable` 的 per-index SMC 路径。相关地址已交给显示审计协作核对。

**WAKER 结论仍未知。** 在上述已经检查的直接函数中未确认 boot-CPU redistributor 的 ProcessorSleep 置位；但未穷尽这些尾部 helper 和安全侧 SMC 的所有副作用，因此既不能宣称“LK 一定把 redistributor 睡眠了”，也不能宣称“整个 quiesce 仅关闭中断接口、肯定保持 awake”。按主分析要求，不由这个未知项追加 GIC 修改。

## 未知项与证据目录

本次没有新的 GICR_TYPER/WAKER、ICC_SRE 权限状态、CNTFRQ/CNTPCT 或实际 IRQ 投递快照；也没有本次 SEC/DXE PC。GIC/Timer 源码链路自洽，不替代包成员检查或硬件执行证据。

所有新增审计数据位于：

`/home/ubuntu/rothko-evidence-20261101/keepalive-clean-records/uefi-timer-trace-01/`

- `trace-index.json`、`initial-observations.json`：身份、DTB 查询、已确认项、未知项。
- `ArmGicDxe.disasm.txt`、`ArmTimerDxe.disasm.txt`：实际链接输出的完整反汇编。
- `lk-quiesce-direct-01.json`、`lk-quiesce-callees-02.json`、`lk-quiesce-strings-01.json`：限定调用流与原始指令/字符串。
- `lk-quiesce-callees-01.json` 有 Capstone signed-immediate 归一化错误，已经明确由 `02` 替代；保留但不作为结论依据。

没有执行任何提到的 LK/SMC 指令，也没有向设备写入寄存器或分区。
