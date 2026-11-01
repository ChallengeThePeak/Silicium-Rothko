# 12 — 33 秒重启的真凶定位：GIC 排除 + 故障信标（22 号镜像）

日期：2026-10-25
背景：16→21 号镜像全部 33 秒被 RGU 看门狗复位；21 号（`nonx`）关掉了
`PcdRemapUnusedMemoryNx` 和 `MEMORY_PROTECTION`，仍然 33 秒。ATF dump 只剩
`pc/lr/sp/pstate`，`pc` 始终落在 `ArmCpuDxe` 的 `CpuDeadLoop()`，
`CpuExceptionHandlerLib.c:438` 的 `ASSERT(FALSE)` 说明进过一次默认异常处理器，
但**故障地址（FAR）和故障指令（ELR）从来没被带出设备**。

本轮做两件事：把 GIC 这条线彻底结掉，再给异常处理器装一个能把 FAR/EC 带出设备的信标。

---

## 1. GIC 地址核实（原厂 DTB 实数，实锤排除）

来源：`work/extracted/vendor_boot_dtb0.txt`

| 节点 | reg | 说明 |
|---|---|---|
| `/interrupt-controller@c400000` | `0x0C400000 + 0x40000`，`0x0C440000 + 0x200000` | `compatible = "arm,gic-v3"`，`#redistributor-regions = <1>`，`interrupts = <1 9 4 0>` |
| `/gic500@c000000` | `0x0C000000 + 0x400000` | `mediatek,gic500`（GICD 别名） |
| `/gic-cpu@c400000` | `0x0C400000 + 0x40000` | `mediatek,gic_cpu` |

即 **GICD = `0x0C000000..0x0C400000`（4 MiB）**，
**GICR = `0x0C400000..0x0C640000`（2.25 MiB，两条 reg 区间首尾相接）**。

算一下 `ArmGicV3Dxe` 的实际用量：GICR 每帧 = RD_base 64 KiB + SGI_base 64 KiB =
128 KiB，8 核 = 8 帧 = **1 MiB**，落在 `0x0C400000..0x0C500000`，离真实边界
（`0x0C640000`）还有 1.25 MiB，离当前映射边界（16 MiB 窗口 → `0x0D400000`）
还有 15 MiB。

结论：**GIC 重分布器扫描不可能是这次异常的来源**。20 号已经把窗口从 2.25 MiB
扩到 16 MiB（7 倍余量）仍然 33 秒，与这里的算术一致——GIC 线关闭。

同理 `PcdRemapUnusedMemoryNx=FALSE` + `MEMORY_PROTECTION=FALSE`（21 号）也没变化，
说明也不是早期 DXE 大面积重设页表属性触发的。

---

## 2. 现场证据复核（21 号 dump）

`work/expdb/expdb-full-20261025-120457.txt`：

```
[RGU] Status: IRQ / HW_WDT                      ← 33.315 s 硬件看门狗
cpu(0) pc:<0000000043782c34> lr:<0000000043782c38> sp:<000000004223ead0> pstate=620003c4
cpu(0) sctlr_el1:30d0198d tcr_el1:280803518 ttbr0_el1:43e7f000 ttbr1_el1:0
cpu(0) sp_el0=4378d1b0 sp_el1=4223ead0
cpu(0) esr_el2:5e000000 far_el2:fef7def4fe78ef4 hcr_el2:100030080080001
```

- `pc` 在 `ArmCpuDxe`（基址固定 `0x43780000`）的 `CpuDeadLoop` 里，`lr = pc + 4`
  是那条 `bl CpuPause` 的返回地址。
- `pstate = 0x620003c4` → EL1t，`sp_el0 = 0x4378d1b0` 落在 `ArmCpuDxe` 的
  `.data`（RVA `0xD1B0`）：同步异常走 SP_EL0 专用异常栈，这与
  `ExceptionSupport.S` 的注释一致，**也再次印证镜像基址就是 `0x43780000`**。
- `esr_el2 = 0x5e000000` → EC `0x17`（EL2 截获 SMC），是 ATF/PSCI 的残留，
  与本次故障无关，别被它误导。

**ATF 只提供 `pc / lr / sp / pstate`（外加 EL2 侧寄存器）**，没有 `ESR_EL1 /
ELR_EL1 / FAR_EL1`。所以「哪条指令、访问了哪个地址」这两件事，靠 dump 本身永远
拿不到——这是本轮要解决的核心限制。

---

## 3. 一个必须纠正的推理错误

前面几轮把「`pc` 落在 `ArmCpuDxe`」直接当成「故障发生在 `ArmCpuDxe`」，
进而得出「显示驱动根本没执行」。**这个推论不成立。**

`ArmCpuDxe` 装上的是**全局向量表**：任何模块、任何时刻发生同步异常，都会进入
`ArmCpuDxe` 里的那份 `CpuExceptionHandlerLib`，然后 `ASSERT(FALSE)`
（`PcdDebugPropertyMask = 0x0F` 已去掉 dead-loop，所以只是打印后返回）
接着 `CpuDeadLoop()`。**栈在 CpuDxe，不代表故障在 CpuDxe。**

反过来有一条正面证据说明显示驱动确实跑过：16 号镜像把
`PcdFrameBufferDelay` 设成 10000 µs，于是 `pc` 停在 DxeCore 的
`cnTPCT` 倒计时循环里；而这个延时只在 **帧缓冲串口（FrameBufferSerialPortLib）
输出换行**时发生——**能走到那一步，说明 GOP 已经装好**，也就是
`RothkoDisplayDxe` 已经成功执行完 `ProbeScanouts` / `InstallGop`。
17 号把延时改成 0、日志降到只报错，才「越过」那段打印，随后撞上异常。

结论：**故障发生在显示驱动装好 GOP 之后的路径上**（BDS 接控制台、GraphicsConsole
画字、或 1 s 周期 `Refresh()` 推帧），而不是 CpuDxe、GIC、页表属性。

---

## 4. 22 号镜像：故障信标（把 FAR/EC 塞进 LR）

不猜了。既然 ATF 会打印 `lr`，而 `lr` 就是挂起瞬间的 `x30`（异常进 EL3 时
通用寄存器不被换出），那就把要带出来的信息放进 `x30`，然后原地自旋。

补丁：`src/uefi-rothko/patches/0002-rothko-fault-beacon.patch`
（作用于 `Mu_Basecore/UefiCpuPkg/Library/CpuExceptionHandlerLib/AArch64/CpuExceptionHandlerLib.c`
的 `DumpCpuContext()` 入口，在任何打印之前）

```c
Beacon  = FAR_EL1 & 0x0000FFFFFFFFFFFF;
if (Beacon == 0) Beacon = ELR_EL1 & 0x0000FFFFFFFFFFFF;
Beacon |= (ESR_EL1.EC & 0xFF) << 56;
asm("mov x30, %0; 1: b 1b" :: "r"(Beacon));
```

- 放在函数最前面，所以**递归异常也照样能带出值**（不再走 `mRecursiveException`
  那条只会写串口的死路）。
- 不再打印——打印走的是扫描不出去的帧缓冲控制台，纯属浪费时间，还可能二次故障。
- 编译产物已反汇编核对（`ArmCpuDxe.efi`，`ArmCpuDxe` RVA）：

```
4d34: ldr  x8, [x19, #0x320]     ; FAR
4d38: ands x8, x8, #0xffffffffffff
4d3c: b.ne 0x4d48
4d40: ldr  x8, [x19, #0x300]     ; ELR（FAR 为 0 时兜底）
4d44: and  x8, x8, #0xffffffffffff
4d48: ldr  x9, [x19, #0x318]     ; ESR
4d50: lsr  x9, x9, #26           ; EC
4d54: bfi  x8, x9, #56, #8       ; lr[63:56] = EC
4d58: mov  x30, x8               ; ← 信标
4d5c: b    0x4d5c                ; ← 自旋，ATF 会把这个地址报成 pc
```

**预期现场**（`ArmCpuDxe` 基址 `0x43780000` 在历次启动中稳定）：

```
cpu(0) pc:<0000000043784d5c> lr:<00ECxxxxxxxxxxxx> ...
```

`lr` 读法：

| 高位（EC） | 含义 |
|---|---|
| `0x24` | 低 EL 数据中止（UEFI 在 EL1，触发者也是 EL1 时为 `0x25`） |
| `0x21` | 指令中止（`FAR` = 取不到的 PC） |
| `0x22` | PC 对齐异常 |
| `0x25` | 同 EL 数据中止 |
| `0x2F` | SError（异步，`FAR` 可能无意义） |

低 48 位就是**故障地址**。举几个一眼能认的例子：

- `0x00 25 0014002000` 类 → 显示寄存器区（`0x14002000`，**当前内存表没映射**）
- `0x00 25 0014602000` 类 → OVLSYS1（已映射，说明不是映射问题是总线/电源域拒绝）
- `0x00 25 00FD9xxxxx` 类 → 帧缓冲越界（看是否超出 `0xFD91F000+0x26E0000`）
- `0x00 25 0048xxxxxx` 类 → pstore / ram_console 区（未映射）
- `0x00 24 00xxxxxxxx` 且 `FAR` 落在 `0x42280000..0x43E80000` 之外 → 堆/栈越界

---

## 5. 镜像与复现

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-22-beacon.img` |
| 大小 | 307,200 B |
| SHA-256 | `f90f3cca0a42c7b7b7fb7d2603a9b20d8865a15832c7f91798fbaf3b082c3061` |
| 结构校验 | 四项 PASS（ARMd / text_offset / image_size / firmware size） |
| 相对 21 号的改动 | 仅新增 `patches/0002-rothko-fault-beacon.patch` |

链路验证（不靠猜）：

1. `CpuExceptionHandlerLib.obj` 重建（时间戳 14:13 之后）；
2. `ArmCpuDxe.efi` 反汇编含 `0x4d34..0x4d5c` 信标序列；
3. `FV/Ffs/*ArmCpuDxe*.ffs` 在偏移 `16780` 处含信标字节；
4. `FV/FVMAIN.Fv`（未压缩 FV）在偏移 `68992` 处含信标字节；
5. `SILICIUM_UEFI.fd` → `boot-rothko-uefi-22-beacon.img`，四项结构 PASS。

复现：

```bash
wsl -d Ubuntu2404 -- bash -lc 'bash "/mnt/d/漏洞/UNIXNU/适配K70U/src/uefi-rothko/scripts/build-uefi-rothko.sh"'
wsl -d Ubuntu2404 -- bash -lc 'cd "/mnt/d/漏洞/UNIXNU/适配K70U" && python3 src/uefi-rothko/scripts/pack-bootimg-rothko.py --output bringup/boot-rothko-uefi-22-beacon.img --work-dir /mnt/d/漏洞/UNIXNU/适配K70U/work/bootimg-22'
```

生成补丁的脚本：`scripts/make-fault-beacon-patch.py`（`CpuExceptionHandlerLib.c`
在本机是 CRLF，构建脚本第一步会把它规范化成 LF，所以补丁必须按 LF 生成——
脚本会自动跟随文件当前行尾）。

> 说明：`0002` 是**诊断补丁**，会让异常处理器不再打印任何东西直接自旋。
> 定位完成后请删除该补丁（构建脚本按 `patches/0*.patch` 全量应用），
> 它不会自动失效。

---

## 6. 判读表：22 号刷完只看两行

刷完仍然是 33 秒重启，抓 expdb（`scripts/dump-expdb-full.sh`）后只看：

1. `cpu(0) pc:` → 是否是 `0x43784d5c`。
   - **是** → 信标命中，`lr` 有效，直接进第 2 步。
   - **不是**（还是 `0x43782c**`）→ 说明异常发生在 `ArmCpuDxe` 装向量**之前**
     （SEC/PEI 或 CpuDxe 自身早期），那我们改在 SEC 的 `Helper.S` 里装同款信标。
2. `cpu(0) lr:` → `0x00ECxxxxxxxxxxxx`，按第 4 节的表解码出 EC 和故障地址。

拿到 FAR 之后，就不再需要「猜一版、刷一次」了：任何一个具体地址都能在
`MemoryMapLib.c` 和驱动源码里被唯一确定（映射内/映射外、偏移第几层、越界多少）。

---

## 7. 22 号实测结果（2026-10-25 14:19，adb 抓取）

dump：`work/expdb/expdb-full-20261025-141928.bin`（128 MiB，`.txt` 已导出）
对应镜像：`kernel_sz=0x000482fd`

```
NOTICE: (0)[33.327586]cpu(0) pc:<0000000043784d5c> lr:<2500fffffffffff1> sp:<000000004223ead0> pstate=20003c4
NOTICE: (0)[33.328170]cpu(0) sctlr_el1:30d0198d tcr_el1:280803518 ttbr0_el1:43e7f000 ttbr1_el1:0
NOTICE: (0)[33.328695]cpu(0) sp_el0=4378d1d0 sp_el1=4223ead0
```

- `pc = 0x43784d5c` → **正是信标的自旋点**（RVA `0x4d5c` + 基址 `0x43780000`），
  信标命中，`lr` 有效。
- `lr = 0x2500fffffffffff1` 解码：

| 字段 | 值 | 含义 |
|---|---|---|
| `lr[63:56]` | `0x25` | **ESR_EL1.EC = 0x25**，同 EL 的数据中止（Data Abort, same EL） |
| `lr[55:0]` | `0x0000fffffffffff1` | FAR = `0xFFFFFFFFFFFFFFF1` = **-15**（空指针减 0x10 那一类的野地址） |

- `sp_el0 = 0x4378d1d0`（比 21 号的 `0x…1b0` 高 0x20，信标本身用的栈更少，自洽）。

也就是说：**不是取指错误、不是对齐错误、也不是 SError，而是一次真的 load/store
打到了 `0xFFFFFFFFFFFFFFF1`。** 典型形态是 `CR(ptr, TYPE, Member)` /
`CONTAINING_RECORD` 一类「基址 + 结构体成员偏移」的指针运算，基址是 1 或 0、
成员偏移 0x10，于是有效地址 = 1 − 0x10 = −0xF。

**现在缺的只剩「哪条指令」。** 22 号的编码把 56 位全给了 FAR，所以出了 PC
盲区——这是下一版要修的地方。

## 8. 23 号：把故障 PC 编进去（v2 编码）

`patches/0002-rothko-fault-beacon.patch` 已改成 v2：

```
lr[63:56] = ESR_EL1.EC
lr[55:24] = ELR_EL1[31:0]   ← 故障指令地址（UEFI 代码都在 4 GiB 以下）
lr[23:0]  = FAR_EL1[23:0]   ← 复核用（应读出 0xff_fff1）
```

反汇编核对（`ArmCpuDxe.efi`，RVA）：

```
4d34: ldr  x8, [x19, #0x318]   ; ESR
4d40: lsl  x8, x8, #30
4d44: and  x8, x8, #0xff00000000000000
4d48: bfi  x8, x9, #24, #32    ; ELR[31:0] -> lr[55:24]
4d50: bfxil x8, x9, #0, #24    ; FAR[23:0]  -> lr[23:0]
4d54: mov  x30, x8
4d58: b    0x4d58              ; ← 预期 pc = 0x43784D58
```

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-23-beacon-elr.img` |
| 大小 | 307,200 B |
| SHA-256 | `b6b0352bfcd282cab1a67b9eba5d0c0ed1c97dd791550d6064d86eb1c796a9ab` |
| 结构校验 | 四项 PASS |

判读：`pc` 应为 `0x43784d58`，`lr` 形如 `25 4378XXXX fffff1`；
`0x4378XXXX` 就是那条出事的指令地址，直接丢进 `llvm-objdump` 按模块基址换算即可，
连源码行都能对上（DEBUG 构建）。

## 9. 23 号实测（14:24）与 24 号（带模块名）

```
cpu(0) pc:<0000000043784d58> lr:<2543b86bd4fffff1> sp:<000000004223ead0> pstate=820003c4
```

| 字段 | 值 |
|---|---|
| `pc` | `0x43784d58` = v2 自旋点（RVA `0x4d58` + `0x43780000`）→ 信标命中 |
| `EC` | `0x25`，同 EL 数据中止（与 22 号一致） |
| **故障 PC（ELR）** | **`0x43b86bd4`** |
| `FAR[23:0]` | `0xfffff1`（与 22 号的 `…f1` 吻合） |

但 ELR 是绝对地址，模块加载基址由 DXE 运行时决定（`ArmCpuDxe` 固定
`0x43780000`，DxeCore 在 `0x43b7xxxx` 一带），单靠绝对地址无法唯一确定模块：
`0x43b86bd4` 在 `0x43b86000`（RVA `0xbd4`）、`0x43b85000`（RVA `0x1bd4`）等
多个假设下都"看似合理"。`scripts/find-fault-image.py` 按 4 KiB 对齐穷举出
300 个候选，无法收敛。

**24 号：把模块名带出来（v3）**

```
lr[63:32] = 故障镜像基名的前 4 个 ASCII 字符（取自 EFI debug image table）
lr[31:24] = EC
lr[23:0]  = RVA = ELR - ImageBase
```

反汇编（`ArmCpuDxe.efi`）：`bl GetImageName` → `bl BaseName` → 4 字符循环拼 tag →
`lsl x9,#32` → `bfxil x9,x10,#2,#32`（EC 落 bits 31:24）→ `bfxil x9,x8,#0,#24`
（RVA）→ `mov x30,x9 @0x4dac` → 自旋 `@0x4db0`。

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-24-beacon-name.img` |
| 大小 | 307,200 B |
| SHA-256 | `eb9af0a99fae7596d16a29d1a87896bc4e1b0ea17d987ade667b163b06f34a87` |
| 结构校验 | 四项 PASS |
| FV 内含新信标 | FVMAIN.Fv @69076、ArmCpuDxe.ffs @16864 |

判读：`pc = 0x43784db0`；`lr` 形如 `47726170 25 000bd4` → 前 8 位十六进制是
`Grap`（GraphicsConsoleDxe）之类，后 6 位是模块内 RVA，直接 `objdump` 定位。

## 10. 24 号实测（14:33）：定位到 DxeCore!CoreFreePoolI

```
cpu(0) pc:<0000000043784db0> lr:<4478654325007bd4> pstate=620003c4
```

| 字段 | 值 | 含义 |
|---|---|---|
| `pc` | `0x43784db0` | v3 自旋点 |
| `tag` | `0x44786543` | **`DxeC`** → DxeCore |
| `EC` | `0x25` | 同 EL 数据中止（与前两版一致） |
| `RVA` | `0x007bd4` | DxeCore 内偏移 |

模块基址 = `0x43b86bd4 - 0x7bd4` = **`0x43b7f000`**（顺带确定了 DxeCore 的加载址，
之前按 `0x43b7a000` 推测是错的）。

`scripts/map-whereis.py` 查 map：**`CoreFreePoolI` +0x28**。反汇编：

```
7bac: CoreFreePoolI:
7bc8: sub  sp, sp, #0x10
7bcc: mov  x20, x0               ; x0 = Buffer
7bd0: mov  w8, #0x6870           ; 'p','h'
7bd4: ldr  w26, [x20, #-0x18]!   ; ← 读 POOL_HEAD.Signature（前变址写回）
7bd8: movk w8, #0x3164, lsl #16  ; w8 = 0x31646870 = "phd0"/"phd1"
7bdc: orr  w9, w26, #0x1000000
7be0: cmp  w9, w8
7be4: b.ne 0x7c1c                ; 签名不符 → 走错误分支
```

代入 FAR：`Buffer - 0x18 = 0xFFFFFFFFFFFFFFF1` → **`Buffer = 9`**。

**结论：某处调用了 `FreePool((VOID *)9)`。** 9 是真值不是随机数：
它符号扩展后正好给出 `-15`，不是 NULL（NULL 会得到 `-0x18`）。

## 11. 25 号：把调用者带出来（v4）

v1→v3 只能定位"在哪挂"，还差"谁挂的"。`CoreFreePoolI` 在 `[sp+0x50]` 保存
`{x29,x30}` 后又 `sub sp,#0x10`，因此签名检查时：调用者帧指针在 `SP+0x60`、
返回地址在 `FP+8`。v4 沿帧链上溯，跳过 DxeCore 自身的帧，取第一个外部模块：

```
lr[63:32] = 该模块基名前 4 字符
lr[31:24] = 0xC1（标记：这是调用者帧，不是故障 ELR）
lr[23:0]  = 返回地址在该模块内的 RVA（找不到则 0xFFFFFF）
```

反汇编（`ArmCpuDxe.efi`）：`sub w9,w21,w28` → `and x22,x9,#0xffffff` →
`orr x8,x22,x8,lsl #32` → `orr x8,x8,#0xC1000000` → `mov x30,x8 @0x4e20` →
自旋 `@0x4e24`。

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-25-beacon-caller.img` |
| 大小 | 307,200 B |
| SHA-256 | `def0d52d618568a481c2b765a2923c7c266f43a6076dcf75c120402a24fbcb1d` |
| 结构校验 | 四项 PASS |

预期：`pc = 0x43784e24`，`lr` 形如 `47726170 C1 001234`。

### 静态排查记录（为拿到调用者后做准备）

控制台链路里所有 `FreePool` 已过一遍：

- `GraphicsConsole.c:448/730/735/741`：`FreePool(Info)`，`Info` 来自
  `GOP->QueryMode`（我们返回 `AllocateCopyPool` 的副本，合法）。
- `GraphicsConsole.c:1638/1675/1679`：`Blt` / `String` / `FontInfo`，
  均由 `AllocateZeroPool`/`AllocateCopyPool` 分配且判空。
- `ConSplitter.c:2719`：**首次接入 GraphicsOutput 时，`FreePool(Private->GraphicsOutputModeBuffer)`
  发生在第一次赋值之前**；若 `Private` 是 `AllocateZeroPool` 则为 `FreePool(NULL)`
  （`CoreFreePool` 会先判空），给不出 9。
- `ConSplitter.c:2738/2771/2775/2882/2886`：`FreePool(Info)`，同上来自 `QueryMode`。

9 这个值目前没有静态来源，必须靠 v4 的调用者地址反查。

## 12. 一次性修法：池硬化 + 修真实双重释放（26 号镜像）

子代理并行审计（`D:/tmp/rothko-audit/`：`bin-hunter2.md`、`src-audit.md`，342 个
疑似调用点筛到 71 个真 `gBS->FreePool`）后收敛出结论：**`9` 不是随机野指针，是
被截断成 32 位的状态码**——全树唯一能产出 `9` 的字面来源是
`EFI_OUT_OF_RESOURCES = 0x8000000000000009`（低 32 位即裸 `9`，再符号扩展正好是
`-15`）。也就是说「32 位状态落进 64 位指针槽 / 出参未写 / 先 free 后复用」之一。

本轮不再逐层猜，直接上三路齐下：

### 1. DxeCore 池入口硬化（`patches/0003` → `MdeModulePkg/Core/Dxe/Mem/Pool.c`）

`CoreFreePool()` 原来只判 NULL 就直接把指针交给 `CoreFreePoolI`，后者必然解引用
`Buffer-0x18` 读池头签名——任何坏指针都会变成致命 data abort。现在拒绝
「`Buffer < 0x1000` 或非 8 字节对齐」的指针，返回 `EFI_INVALID_PARAMETER`。

反汇编核对（`DxeCore.efi`，`CoreFreePool` RVA 0x7f40）：

```
7f50: mov  x19, #0x2              ; 默认返回 EFI_INVALID_PARAMETER
7f54: movk x19, #0x8000, lsl #48
7f58: cbz  x0, 0x7fa4             ; NULL
7f60: cmp  x0, #0x1, lsl #12      ; ← Buffer < 0x1000
7f64: b.lo 0x7fa4                 ; → 直接返回，不再解引用
7f68: and  x8, x20, #0x7
7f6c: cbnz x8, 0x7fa4             ; ← 非 8 字节对齐
7f88: bl   0x7ba0                 ; → CoreFreePoolI
```

**这一条就足以让 33 秒死循环消失**：`FreePool(9)` 从「整机 data abort + 33 秒后
看门狗收尸」变成「返回一个错误码」，固件继续跑。

### 2. 修 BDS 控制台连接路径上的真实双重释放（`BmConsole.c`）

`BmGetGopDevicePath()` 里 `TempDevicePath` 释放后没有置空，紧接着又被释放一次；
而且当递归查找返回 NULL 时，尾部那段会把**正要返回给调用者的 `GopPool`** 释放掉。
双重释放会污染池的空闲链表，正是后续出现「指针槽里是小整数」的机制之一。已改为
释放后置 NULL 并删掉尾部那次重复释放。

### 3. 其它

- `GraphicsConsole.c:1255`：`FreePool(Private->LineBuffer)` 后补 `= NULL`，堵住
  `SetMode` 分配失败时旧指针被二次释放。
- `RothkoDisplayDxe` 的 `Blt`：对 `DestinationX/Y + Width/Height` 与
  `FrameBufferSize` 做边界校验，超窗不再走 `WriteBackDataCacheRange`，改为返回
  `EFI_INVALID_PARAMETER`（防 cache 维护打野）。
- v4 故障信标**保留**（`patches/0002`）：只在真出异常时生效，不影响正常启动；
  万一还有问题，下一次抓 expdb 直接给出调用者模块+RVA，不用再猜。

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-26-hardened.img` |
| 大小 | 307,200 B |
| SHA-256 | `18ee0fbf4602ebfec54d521016070ffbf956f20014ac73fbc1ab77bd7e47e035` |
| 结构校验 | 四项 PASS |
| 相对 21 号 | `patches/0002`（信标 v4）+ `patches/0003`（池硬化/双释放）+ 驱动 Blt 边界校验 |

刷完预期：**不再 33 秒复位**；屏幕上应能看到 `Project Silicium`/`ROTHKO:` 文字
（帧缓冲串口控制台在等 DSI 推帧，若仍是 logo，说明推帧仍未通，但固件会继续跑下去，
看门狗之前就能看到差别）。若仍复位，抓 expdb，`pc` 应为 `0x43784e24`，`lr` 直接
给出调用者模块名+RVA。

## 13. 26 号实测与 27 号生存版（15:29）

26 号上机结果（用户实测）：**复位提前到 ~20 秒，且没有 AEE/ELK dump，直接亮屏**。
抓 expdb 核对：里面仍是 24 号那次现场（`pc=0x43784db0`、`lr=DxeC 25 007bd4`、
33.3 s 看门狗），`kernel_sz=0x48381` 对应 24 号——**26 号没有产生任何崩溃记录**，
说明池硬化生效，固件跑过了原来毙命的那一步；20 秒复位是一次没有 dump 的干净复位
（RGU 是 33 s，所以不是看门狗）。

排查软件复位来源：全树只有两处 `gRT->ResetSystem` 可达（`BmDriverHealth.c:739`
DriverHealth 要求重启、`BmMisc.c:370` 内存类型信息变化）；
`PcdResetOnMemoryTypeInformationChange` 已是 FALSE，`ResetIfBootNextFailsDxe`
未编入本 FV，`BdsEntry` 末尾是 `CpuDeadLoop()` 而非复位。两处都先堵掉。

### 27 号 `boot-rothko-uefi-27-survival.img`

| 改动 | 位置 |
|---|---|
| 关掉 MTK RGU 看门狗（`WDT_MODE <- KEY` 清 ENABLE） | `RothkoDisplayDxe` 入口 |
| 堵掉 DriverHealth 的 warm reset | `patches/0003` → `BmDriverHealth.c` |
| 堵掉内存类型信息变化的 warm reset | `patches/0003` → `BmMisc.c` |
| 池入口硬化、双释放修复、`LineBuffer` 置 NULL、`Blt` 边界校验 | 同 26 号 |

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-27-survival.img` |
| 大小 | 307,200 B |
| SHA-256 | `665560fe380be9cefb3751d7f410c4c54fabe73940c5950223333e2f82c00f6c` |
| 结构校验 | 四项 PASS |
| FVMAIN 余量 | 736 B |

判据：

| 现象 | 结论 |
|---|---|
| **一直不复位**（logo 不动、或变深蓝/出文字） | 固件站稳了；接下来只攻 DSI 推帧 |
| 仍 ~20 秒复位 | 不是 RGU、不是那两处软件复位；下一步加「把进度写进 ram_console」的自报位置 |

## 14. 27 号实测：复位是 PMIC 全复位（15:41）

27 号仍 ~15 秒复位。抓 expdb + 内核侧交叉核对：

- expdb 里仍是 24 号旧现场（无新崩溃记录）；
- 最近一次 preloader 日志明确写着 **`kedump: last is full pmic reset!`**；
- `[RGU] MODE: 0x4D`（ENABLE 仍在）、`LENGTH: 0xFFE0`、`SWSYSRST: 0x0`；
- 全树 `gRT->ResetSystem` 可达处已堵（`BmDriverHealth`/`BmMisc`），`ResetIfBootNextFailsDxe`
  未编入，`UiApp` 未编入。

两个结论：

1. **复位不是 AP 看门狗**（LENGTH 0xFFE0 ≈ 35 s，与 15 s 对不上），也不是软件复位
   （SWSYSRST=0），是 **PMIC 全复位**——这正是它不产生任何 crash dump 的原因。
2. **我在 27 号里写的那条关看门狗没生效**：MTK 的 `WDT_MODE` 只在写
   `WDT_RESTART`(KEY=0x1971) 时才锁存，只写 MODE 不算数。28 号已补上
   （反汇编核对：`mov w1,#0x22000000 → bl MmioWrite32`，再
   `add x0,x19,#8; mov w1,#0x1971 → bl MmioWrite32`）。

### 28 号 `boot-rothko-uefi-28-bisect-nomx.img`（一次二分）

`ROTHKO_BISECT_NO_MMIO = 1`：驱动入口只做「关看门狗 + DEBUG + return」，
**不碰任何显示 MMIO、不装 GOP、不起定时器**。

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-28-bisect-nomx.img` |
| 大小 | 307,200 B |
| SHA-256 | `24694604ce354b85f9138f3ef31e87017d351cffa555c5513899b2ef9dd4510b` |
| 结构校验 | 四项 PASS |

| 现象 | 结论 | 下一步 |
|---|---|---|
| **不再复位**（停在 logo 不动） | 触发源在「GOP + 控制台」这条链上 | 29 号：保留 GOP 与控制台，但去掉所有 DSI/MUTEX 写与 OVLSYS1 读 |
| 仍 ~15 秒复位 | 与显示/控制台无关 | 二分 BDS 其它路径（变量存储、RamManagerDxe、USB/SD 探测） |

## 15. 对照 dali 实现（Redmi K80 Ultra，MT6991）+ OnePlus MT6989 源码

dali 的实现在 `localhosts-A/UEFI-Dali`（已拉到 `D:/tmp/dali/`），核心是
`Platforms/Xiaomi/daliPkg/Drivers/DisplayDxe/DisplayDxe.c`。设备是 Redmi（小米不开源
MT6989 显示代码），所以 **SoC 级寄存器一律以 OnePlus MT6989 开源码为准**
（`src/OnePlusOSS-mt6989/kernel/kernel_device_modules-6.1/drivers/gpu/drm/mediatek/mediatek_v2/`），
dali 只当「UEFI 侧写法」的参照。

### 用 OnePlus 源码坐实的三条

| 项 | 值 | 出处 |
|---|---|---|
| mutex EN / MOD / SOF / MOD2 | `0x20` / **`0x30`** / **`0x2C`** / `0x34` | `mtk_drm_ddp.h:40-45` + `MT6983_DISP_MUTEX0_MOD0/SOF`（mt6989_ddp_driver_data 复用） |
| DISPSYS1 mutex 的 DSI0 位 | **BIT(15)** | `MT6989_MUTEX1_MOD0_DISP_DSI0 BIT(15)` |
| DSI 触发（CPU 路径） | **`writel(0); writel(1);` 并停在 1** | `mtk_dsi_start()`：「both CMD and VDO would use it」 |
| DSI MODE_CTRL | **`0x14`** | `mtk_dsi.c:124` |

⇒ 我们的 mutex 寄存器偏移和 DSI0 位**本来就对**（dali 的 MT6991 是 MOD `0x34`/SOF `0x30`，
不能照抄）。真正抄错的是 **DSI_START 的三拍**。

### 29 号改动（照 dali + MT6989 真偏移）

1. **`PushFrame` 改回 `mtk_dsi_start` 语义**：`0 → 1` 并停在 1，删掉尾拍 `0`，**不再写 CMDQ**。
   那三拍 0→1→0 是 `mtk_dsi_config_trigger` 给 GCE 原子回放用的；CPU 背靠背重放会把
   传输掐断。dali 就是这条，且实测出画面。
2. **提交前查命令模式**：`DSI_MODE_CTRL(0x14) & 3 == 0`，否则拒绝推帧（dali 同款检查）。
3. **硬要求存在一个地址 == fb base 的扫描层**（dali 是强制项，我们原来只是「优先」），
   否则拒绝推帧——否则控制台文字会画进一块没人扫的内存，屏幕永远是 logo。
4. 保留：pitch 从 OVL 回读（rothko 面板 1220 宽但硬件 pitch 是 1248 像素=4992 字节，
   不能像 dali 那样用 `width*4`）；镜像多扫描层；1s 定时器。

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-29-dali-align.img` |
| 大小 | 307,200 B |
| SHA-256 | `eab2052ecaf67db6b24f3eef6504ba3863da87b66084d605526a28a4bb8efb4a` |
| 结构校验 | 四项 PASS |
| 新代码已编入 | `no scanout layer at` / `is not command mode` 字符串均在 .efi 里 |

判据：

| 屏幕 | 结论 |
|---|---|
| **整屏变深蓝/出文字** | OVL→DSC→DSI 推帧通了，只剩控制台排版 |
| 仍是 logo | 推帧仍没到面板——下一轮只查 OVL 路由与 DSC（用 mediatek-drm.ko 的 OVL driver_data 对齐） |
| 花屏 | 推上了，pitch/格式不对 |

## 16. 30 号：去掉 HALT 死循环 + dali 全面对齐（16:25）

### 根因（为什么一直 logo + 15 秒 PMIC 全复位）

`ROTHKO_HALT(code)` 是 `b .` 死循环。`StartRefresh` 任一步失败（CMD 模式检查不过、
没扫描层、没 mutex）都会进死循环 → PMIC 看门狗 ~15 秒收尸 → **PMIC 全复位（无 dump）**。

这就是为什么：
- 屏幕永远 logo（推帧代码从未执行到）
- 15 秒复位、无 AEE dump（PMIC 全复位不产生 ATF crash 记录）
- 28 号（不碰显示）也复位（DXE 后续某处也死循环，或 PMIC WDT 本身）

### 30 号改动

| # | 改动 | 效果 |
|---|------|------|
| 1 | `ROTHKO_HALT` 改为 `DEBUG_ERROR` + `return`（不再 `b .`） | **15 秒 PMIC 复位直接消失** |
| 2 | CMD 模式检查降级为警告（VDO 也推帧） | 不再因 MODE_CTRL 读数异常而放弃 |
| 3 | 补上 DTB 里的 `disp1-mutex0@14020000` | 5 个 mutex bank 全扫 |
| 4 | mutex 识别改为「DSI0 + OVL」双条件（dali 同款） | 避免 BIT(15) 在别的 bank 撞上 DLI_ASYNC0 |
| 5 | StartRefresh 失败 → `return`（GOP 保留） | BDS 能继续跑，控制台可画字 |

反汇编核对：`b 9000b` 自旋 = **0 个**（旧版每条 HALT 一个），
`0x14020000` 在 .rodata 常量池（offset 0x5204），
"pushing anyway" / "HALT code" 字符串均在 .efi 里。

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-30-nohalt.img` |
| 大小 | 307,200 B |
| SHA-256 | `bc10d523128e2244a4866acdcf8a35320c78dd29fab219d49da795c90da9cd23` |
| 结构校验 | 三项 PASS |

### 判据

| 现象 | 结论 |
|------|------|
| **不再复位**（logo 不动 / 深蓝 / 出文字） | HALT 死循环是复位根因，固件站稳了 |
| 深蓝或出文字 | 推帧通了 |
| 仍 logo 但不复位 | 推帧没到面板，下一轮只查 OVL→DSC→DSI 路由 |
| 仍 ~15 秒复位 | PMIC WDT 本身，需走 SPMI 关掉（下一轮做） |

## 17. 30 号实测：仍是 15 秒，但复位性质已变（16:27）

30 号去掉 HALT 死循环后，expdb **零崩溃记录**（`kernel_sz` 0 条、`cpu(0)` 0 条）——
死循环确凿消失了。但 15 秒复位仍在。

最后一次启动的 RGU 寄存器给出了复位性质：

| 寄存器 | 值 | 含义 |
|--------|-----|------|
| `g_rgu_status` | **0x2** | **软件看门狗复位**（bit 1） |
| `SWSYSRST` | 0x0 | 没人写软件复位寄存器 |
| `kedump` | **NOT full pmic reset** | PMIC 排除 |
| `exp_type` | 0x0 | 无 CPU 异常 |
| `REQ_MODE` | 0x7D21E3 | 预加载器配的复位请求路由 |
| `NONRST_REG` | 0x0 | 我们没写心跳 |

结论：**RGU 软件看门狗**（dual mode 二次超时）在 15 秒收尸。
我们的 `WDT_MODE = 0x22000000` 直写没关掉它——可能被覆盖或顺序不对。

### 31 号：保活策略

不再赌"关掉"，改成**持续喂狗**：

1. **读-改-写关 EN**：`WDT_MODE = (read & ~EN) | KEY`，再 `WDT_RESTART` 锁存
2. **独立 1 秒定时器踢 `WDT_RESTART`**（不依赖 StartRefresh 成功与否）
3. **心跳写 `NONRST_REG`**（`0x40000000 | 秒数`），下次 preloader 日志自动报告存活秒数

| 项 | 值 |
|---|---|
| 文件 | `bringup/boot-rothko-uefi-31-wdtkeep.img` |
| 大小 | 307,200 B |
| SHA-256 | `deb0a5e985c5da6ccb53b52eecf00ddd55475150382af25a4b91633c35138ca9` |
| 结构校验 | PASS |

### 判据

| 现象 | 结论 |
|------|------|
| **不再复位** | 踢狗生效，固件站稳 |
| 仍复位但 `NONRST_REG` 非零 | 心跳在跑 → WDT 不是 RGU，是别的定时器 |
| 仍复位且 `NONRST_REG` 为 0 | 我们的驱动没跑到入口（更早的问题） |
| 屏幕出蓝/文字 | 推帧通了 |
