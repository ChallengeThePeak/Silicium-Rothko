# 编译带 pstore 日志的 UEFI boot

本文只讨论 K70U / `rothko`，以及同机型不同系统版本、`vendor_boot`
带来的差异，不讨论跨机型移植。产物是替代 Android 内核入口的实验性 UEFI，
不是修改后仍能启动 Android 的 Linux 内核。

当前低日志版本已经实机进入 DXE Core，并在 `Gcd.c(2420): Found` 断言处停止。
因此，“能编译、能进入 UEFI、能留下 pstore”不等于已经能启动 XNU。
下面沿用这条已测试的编译和打包路线；新目录首次安装依赖的过程没有重新全量实测。

## 1. 源码与环境

使用 Linux / WSL，已验证的工具链为 Python 3.12、Clang/LLVM 18、LLD。
**WSL 的 VHDX 本身要位于 D 盘**，仅把源码放在 `~` 并不能保证不占 C 盘。
源码、虚拟环境、Build 和缓存放在这个 WSL 的原生 ext4 中；不要在 `/mnt/f`
上编译整个 EDK 工程。现有环境可直接复用，不需要清缓存或重装工具链。

新建工作目录时按下面布局克隆；已有工程不要照抄命令覆盖或移动：

```bash
mkdir -p "$HOME/k70u"
cd "$HOME/k70u"
git clone --recurse-submodules https://github.com/ChallengeThePeak/Silicium-Rothko.git
git clone https://github.com/UniXNU/UniXNU.git
git -C UniXNU checkout 67df14de69ae6f6ffc3480b30b70ce7667a3bd32

export PORT="$HOME/k70u/Silicium-Rothko"
export UEFI="$PORT/uefi-mtk-reference"
export INPUT="$HOME/k70u/rothko-stock-3.0.303"
export OUT="$HOME/k70u/rothko-pstore-build"
mkdir -p "$INPUT" "$OUT"

git -C "$HOME/k70u/UniXNU" apply --check "$PORT/patches/unixnu-rothko-initrd.patch"
git -C "$HOME/k70u/UniXNU" apply "$PORT/patches/unixnu-rothko-initrd.patch"
```

私有仓库需要事先配置自己的 GitHub 读取凭据。根仓库固定 UEFI 和 Basecore
子模块提交，不要用 `submodule update --remote` 替代递归克隆。
补丁只给 UniXNU initrd 驱动增加 FAT 子区间的 offset/size 支持，不能省略；
已有这部分改动时不要重复应用。

目录关系是构建输入的一部分：`tools/boot_v4.py` 从主仓库的同级目录寻找
`UniXNU/scripts`；`DeviceBuild.py` 从 UEFI 目录寻找 `../../UniXNU/package`。
上述嵌套布局同时满足两者，单独复制 UEFI 文件夹不一定满足。

本机已存在的编译目录是 `/home/w1/k70u/uefi-mtk-reference`，虚拟环境是其中的
`.venv-linux-build`，EDK 包依赖位于 `/home/w1/UniXNU/package`。
复用本机目录时将 `UEFI` 设为该路径、`PORT` 设为
`/mnt/f/k70u/os/3.0.303/K70U-PORT` 即可，不必再克隆一套。

仅在全新 Ubuntu 环境中安装依赖并初始化构建工具：

```bash
sudo apt update
sudo apt install -y git ca-certificates curl build-essential uuid-dev nasm \
  clang llvm lld python3 python3-venv python3-pip liblz4-1 dosfstools
cd "$UEFI"
python3 -m venv .venv-linux-build
source .venv-linux-build/bin/activate
python -m pip install -r pip-requirements.txt
python Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --setup
python Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --update
```

Python 至少 3.11；`DeviceBuild.py` 使用 `/usr/bin/` 下的无版本号 LLVM 工具。
若只安装了 `clang-18` 等带后缀的命令，需要使构建配置实际指向它们，不能只检查
`clang-18 --version`。打包时还需要 `llvm-objcopy`、`llvm-nm` 和可加载的 `liblz4`。
`--setup` / `--update` 只用于首次准备缺失依赖，不是每次编译的前置步骤。

## 2. 准备模板、FAT 和 vendor 偏移

在 `$INPUT` 放入目标系统版本、目标槽位对应的完整原厂分区镜像：

- `boot.img`：带原有 AVB 尾部，不能是裁掉尾部的解包内核。
- `init_boot.img`：同套原厂模板；不要把 KSU 备份当作 UEFI 的 FAT 输入。
- `vendor_boot.img`：必须对应实际启动时保留在手机上的那个版本。

打包只读取模板，输出到 `$OUT`，不修改原厂文件，也不生成或刷写 `vendor_boot`。
先创建一个新的 1 MiB FAT12 裸文件系统镜像，足够用于当前早期日志实验：

```bash
export FAT="$OUT/init_boot_fat.img"
mkfs.fat -C -F 12 "$FAT" 1024
```

已有 FAT 时直接指定其路径，不要重新格式化。这里没有 MBR/GPT，也不是 CPIO，
不能再把它 gzip/lz4 压缩后塞进 `init_boot`。空 FAT 不是 XNU 启动盘；
当前 SEC/DXE 日志在加载其中的系统载荷之前产生，不需要先准备 XNU 根文件系统。

编译前用仓库已有解析器取得 normal vendor ramdisk 的**压缩字节数**：

```bash
python3 - "$PORT" "$INPUT/vendor_boot.img" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]) / "tools"))
from boot_v4 import normal_vendor_ramdisk_size
size = normal_vendor_ramdisk_size(Path(sys.argv[2]).read_bytes())
print(f"PcdUniXNURamDiskOffset|{size:#x} ({size} bytes)")
PY
stat -c '%s' "$FAT"
```

将结果填入 `$UEFI/Platforms/Xiaomi/rothkoPkg/UniXNUConfig.dsc.inc`，然后再编译。
本次 3.0.303 模板和 1 MiB FAT 对应：

```ini
[PcdsFixedAtBuild]
  gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskOffset|0x02719743
  gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskSize|0x00100000
```

这里的 offset 是 LK 拼接后的 FDT initrd 中、FAT 前面的 vendor ramdisk 长度，
不是分区内的文件偏移，也不是解压后的 CPIO 大小，**不要自行页对齐 offset**。
size 则必须等于 FAT 文件的实际字节数且为 512 的倍数。

## 3. 编译带日志的 FD

```bash
cd "$UEFI"
source .venv-linux-build/bin/activate
python Platforms/Xiaomi/rothkoPkg/DeviceBuild.py \
  TARGET=DEBUG ENABLE_SECUREBOOT=0 \
  FD_BASE=0x40400000 FD_SIZE=0x200000 FD_BLOCKS=0x200 \
  DEVICE_MODEL=0 DISABLE_DEBUG_MACRO_CHECK=TRUE
```

输出是 `Build/rothkoPkg/DEBUG_CLANGDWARF/FV/SILICIUM_UEFI.fd`，当前配置为 2 MiB。
构建日志在 `Build/BUILDLOG_rothkoPkg.txt`。
`DISABLE_DEBUG_MACRO_CHECK=TRUE` 绕过的是已遇到的构建插件查找自定义包失败问题，
**不是关闭固件日志**。不要直接复用旧 Build 目录里的 FD：切换过低日志/大量日志源码后，
应先完成这一步；编译成功也不代表手头旧镜像已更新。

日志路径已经包含在源码中，不需要额外开启 Android 内核的 pstore 选项：

- `Sec.c` 在早期调用 `PstoreLogBegin()`，写入 `K70U_UEFI_PSTORE_BEGIN`。
- DEBUG 的 `DebugLib` 连接 `BaseDebugLibSerialPort`；`SerialPortLib` 连接
  `FrameBufferSerialPortLib`，先写 pstore 再尝试 framebuffer，黑屏不妨碍这一输出路径。
- 当前掩码为 `0x8007EE0F`，INFO 关闭，保留必要阶段日志；RELEASE 使用 Null DebugLib，
  不能拿它代替本说明的 DEBUG 构建。
- pstore 区域为 `0x48090000 + 0xE0000`，pmsg 在 `0x480F0000`，大小 `0x80000`。
  该区在 `MemoryMapLib.c` 中保留并做 uncached 映射，不能改成可分配堆内存。

`ENABLE_SECUREBOOT=0` 控制 UEFI 自己的 Secure Boot，**不等于关闭 Android AVB**。

## 4. BootShim、legacy LZ4 与 AVB 打包

仍在同一个已激活虚拟环境的 WSL shell 中执行：

```bash
python "$PORT/tools/boot_v4.py" \
  --boot-template "$INPUT/boot.img" \
  --init-boot-template "$INPUT/init_boot.img" \
  --vendor-boot "$INPUT/vendor_boot.img" \
  --uefi "$UEFI" \
  --fd "$UEFI/Build/rothkoPkg/DEBUG_CLANGDWARF/FV/SILICIUM_UEFI.fd" \
  --fd-base 0x40400000 --fd-size 0x200000 \
  --kernel-compression lz4 --preserve-avb-tail \
  --fat-image "$FAT" \
  --boot-output "$OUT/boot-uefi-pstore.img" \
  --init-boot-output "$OUT/init_boot-uefi-pstore.img" \
  --report "$OUT/packing-report.json"
```

脚本会编译 BootShim、拼接 FD、规范化 ARM64 Image 头，再做 **legacy LZ4** 压缩，
放入 v4 `boot` 的 kernel 字段；FAT 放入 v4 `init_boot` 的 ramdisk 字段。
实测模板的输出分别为 64 MiB、8 MiB，大小来自完整模板，不是固定写死的通用值。
已有输出时默认拒绝覆盖；需要重打包时换输出目录，或明确加 `--force`。

**AVB 的准确含义：** `--preserve-avb-tail` 从模板原 payload 结束处开始，
保留后续证书、VBMeta、padding、末尾 `AVBf` 及其原始位置；新 payload 和尾部之间补零。
它不重算被改 payload 的摘要，不生成 OEM 私钥，也不重新签名。因此报告应同时显示
`avb_tail_preserved: true` 和 `avb_payload_resigned: false`。
这仅是在当前已解锁设备和实测 LK 策略下有执行证据的封装方式，不保证严格校验环境会接受。

不要因 v4 头的 `signature_size=0` 就删除尾部，二者不是同一个东西。
当前脚本也不支持非零 GKI signature area，遇到该模板会明确报错。
新 payload 超过原尾部起点时同样会拒绝，不能用 `--force` 绕过空间限制。
通用 `build_uefi.py` / UniXNU bootimg 输出不能直接替代这里的专用打包步骤，
它们没有自动满足本流程的 v4、legacy LZ4 和保留 AVB 尾部这组条件。

报告中还应核对 `kernel_target`、`fd_base`、`fd_bytes`、
`fat_disk_offset_in_initrd`。当前 kernel target 为 `0x40000000`，FD 复制到
`0x40400000..0x40600000`；FD 源从 `0x400000C0` 开始，不能与目标发生部分重叠。
脚本会检查这些封装/复制约束，但**不会把报告中的 vendor 偏移自动写回固件 PCD，
也不会验证整份运行时内存布局**。

## 5. 同机型不同固件的适配问题

这里的 `vendor_boot` 是启动镜像，不是 Android 的 `vendor` 文件系统分区。
UEFI 早期日志不加载 Android vendor 服务；若只是 `vendor` 用户空间文件不同，
不能据此推导 FAT 偏移变化，仍应以实际 `vendor_boot`、FDT 和 LK 交接状态为准。

| 变化 | 影响与处理 |
| --- | --- |
| `vendor_boot` normal ramdisk 压缩长度变化 | FAT 起点变化。重新解析，改 `PcdUniXNURamDiskOffset`，重编 FD，再打包两张镜像；只重新打包不够。 |
| vendor ramdisk 表出现多个 normal fragment，或实际选择规则变化 | 当前解析器只接受唯一、非空的 type 1 fragment，且没有实现任意 board-id/多片段选择。先核对该版 LK 的实际拼接结果，不能改成“取全部 vendor_ramdisk_size”凑数。 |
| FAT 容量变化 | 改 `PcdUniXNURamDiskSize` 并重编；还要确认 `init_boot` 的原 AVB 尾部前有足够空间，保留整个 live initrd 范围。 |
| DTB/DTBO、LK mblock、initrd 地址变化 | 当前 `MemoryMapLib.c` 是 3.0.303 实机快照，包含 DTB `0x47C80000`、initrd `0x66F00000..0x6A6D4000` 等静态保留区。对照目标版本实际传入的 FDT/mblock 修正保留区；否则可能覆盖 initrd/DTB 或把保留内存当堆。 |
| `vendor_boot` 中 kernel load address 变化 | 打包脚本会读新地址，但固件的 BootShim Source、FD、堆栈等静态内存配置不会跟着变化，必须一起核对，不能仅相信打包成功。 |
| ramoops 地址、大小、console/pmsg 分区或 ECC 配置变化 | 同步核对串口库常量、MemoryMap 保留区和目标 Linux 的 ramoops 配置。当前直接写入的是无 ECC 的 12 字节头加环形数据格式，不是任意版本通用的 pstore 写法。 |
| boot/init_boot AVB 封装或验证策略变化 | 使用目标版本完整模板，不能移植旧版本固定尾部偏移。尾部保留不是有效重签；若 LK 拒绝，先区分封装错误和真实验签失败，不要默认刷 vbmeta 或更换 LK。 |
| 槽位中的镜像混用 | `--vendor-boot` 是分析输入，不会把对应版本写进手机。实际启动槽位的 vendor_boot、DTBO 等仍须与分析对象一致；Android 恢复用的 KSU init_boot 要与对应原厂 boot 匹配。 |

同机型也不能把“Android 正常启动”当成上述静态 UEFI 内存布局完全兼容的证明。
但没有证据时，也不把 LK 2.0 + OS 3.0 的组合本身当作故障原因，不要求升级 LK/DA。

## 6. 测试与日志怎么看

本说明不自动刷机。需要实测时使用配套的 `boot-uefi-pstore.img` 和
`init_boot-uefi-pstore.img`，并提前保留该槽位原厂 boot 和可启动的 init_boot。
仅恢复原厂 boot、却留下 FAT init_boot，不能作为完整的 Android 恢复方案。
MediaTek 不依赖 `fastboot boot`；UEFI 本身也没有 Android ADB 服务。

若使用本机 Antumbra：先启动等待端口的命令，再触发 reboot；工程 preloader
只在启动窗口出现。进入 DA 并完成读写后，要显式执行 `antumbra.exe reboot --da ...`，
否则设备仍停在刷写模式。不要把稍后出现的无关 COM5 当成同一窗口。

恢复 Android 后，有 root 时可查看：

```powershell
adb shell 'su -c "ls -l /sys/fs/pstore"'
adb shell 'su -c "cat /sys/fs/pstore/pmsg-ramoops-0"'
```

我们写的是 **pmsg**，不只查 `console-ramoops-0`。暖复位不保证每次都保留 RAM，
LK/Android 也可能覆盖或归档它；`/data/aee_exp` 中有文件不代表就是刚才那次 UEFI。
需要原始分区时，在 DA 中用 Antumbra 的 `upload expdb <文件>` 和
`upload blackbox <文件>` 读取，不是等待 UEFI 出现 ADB。
让 LK 有机会处理上一次崩溃再截获 DA；过早拦住紧接着的 preloader 可能拿到旧 expdb。
已验证的新记录来自先放行下一次完整 LK、再于后续重启截获 DA；不能保证所有复位类型都如此。

实测低日志版本最后可见：

```text
K70U_UEFI_PSTORE_BEGIN
MMU: enabled
SEC: HOB list ok, 134 entries
SEC: FV decompressed (Success)
SEC: loading DXE core
Loading DxeCore at 0x0040E58000 EntryPoint=0x0040E5A800
ASSERT [DxeCore] Gcd.c(2420): Found
```

这说明这次执行已经越过 LK、BootShim、SEC 和 FV 解压，下一步应处理 DXE 内存
资源/HOB 属性问题，不是继续把它归因于 framebuffer 黑屏或 boot 没有执行。
以上 HOB 数量、地址和断言行号是那次构建的观测值，不是新构建必须逐字相同的验收条件。

pmsg 环形区有 12 字节头（`DBGC`、写指针、有效长度），当前实现追加而不清空历史。
检查提取结果要按有效环形区排序，不能凭整块 RAM 中搜到旧字符串判断成功；
结合 blackbox 的 boot_index、实际 kernel_size、pstore CRC 和本次构建信息确认新鲜度。
不要假定某个 boot_index 之后全是 UEFI，也不要用旧 AEE 的 RTC 时间或
`minidump_is_valid=1` 单独证明拿到了新日志。
