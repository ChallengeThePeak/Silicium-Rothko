# K70U UEFI 项目长期记忆

## 目标
Xiaomi Redmi K70 Ultra（rothko / MT6989）用上游 `ChallengeThePeak/Silicium-Rothko`
的 `uefi/rothko` 分支编译 UEFI，最终跑起 UniXNU / XNU。当前阶段：**UEFI 已完整
启动到 BDS**，尚无启动项。

## 关键路径
- 上游源码（WSL）：`/home/ubuntu/rothko-upstream-20261102/uefi-full`
- UniXNU：`/home/ubuntu/UniXNU`（已 checkout 到 `67df14de`）
- 构建：`scripts/wsl-final-build-20261102.sh`（官方 `DeviceBuild.py` + stuart）
- 打包：`scripts/wsl-pack-label-20261102.sh <标签>`（上游 `tools/boot_v4.py`）
- 产物：`bringup/boot-k70u-uefi-<标签>.img` + `init_boot-k70u-uefi-<标签>.img`
- ADB/Fastboot：`I:\刷机\root\scrcpy-win64-v3.2\`（rg 装在 WSL `/home/ubuntu/bin/rg`）

## 相对上游的 6 处改动（都有注释，原件备份在 `~/quarantine/`）
1. `MemoryMapLib.c` 资源属性 `SYS_MEM_CAP_XN`→`SYS_MEM_TESTED`（Gcd.c 要求恰好 P|I|T）
2. `MemoryMapLib.c` 内存表裁到 3 GiB（3–4 GiB 段会 address size fault）
3. `FrameBufferSerialPortLib.c` `FbRegion` 初始化 + 缓存刷新钳制
4. `APRIORI.inc` 移出 BdsDxe（否则早于 HiiDatabaseDxe 调度）
5. `rothko.dsc` `PcdDriverHealthConfigureForm`=零（跳过健康检查）
6. `UniXNUConfig.dsc.inc` 注释两条未声明的 PCD（EDK2 error F001）

## 取日志（务必记住）
- 固件日志只存在于 DRAM：pstore `0x48090000+0xE0000`，上游写 pmsg 到 `0x480F0000`。
- **PSCI SYSTEM_RESET = 冷启动**，DRAM 被清 → pmsg 丢失；**只有看门狗超时复位保 RAM**。
  所以固件在 BDS 末尾只能停住等 WDT，绝不主动复位。
- `console-ramoops-0` 每次开机被内核刷新，存在≠RAM 存活；两者同时消失才是真冷启动。
- expdb / blackbox / pstore 分区都没有固件日志（前两者只有 MTK 元数据，第三个全零）。
- 拉日志：`adb shell su -c "cp /sys/fs/pstore/pmsg-ramoops-0 /sdcard/pmsg.bin"` 再 pull；
  Git Bash 下 adb 路径参数要加 `MSYS_NO_PATHCONV=1`。

## 交付格式（用户指定）
每次给**两个镜像**（boot + init_boot）、**绝对路径**、命令里**不写 adb/fastboot 路径**、
末尾带 `fastboot reboot`。

## 待决
- FAT 盘发布：initrd 总长 `0x3504188` 非 512 倍数 → `UniXNURamDiskDxe` 放弃
- 显示/GOP 缺失，BDS 无法显示 logo 与菜单
- XNU 引导依赖上面两项

## 显示（2026-11-02 已点亮）
- 驱动来源：旧树 `~/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed`
  的 `Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/`。它按 **dali(MT6991)**
  的规则写，**从未在 rothko 上执行过**（当年只进了 APRIORI 的 GUID，没进 FV）。
- 移植要点：`[Components]` 段登记 INF（FDF 的 DXE.inc 只管文件清单，两者都要）；
  `PcdFrameBufferStride` 上游没有（新增 0x0000A006）；设备树区域必须叫 **"LK DTB"**
  （驱动用 `LocateMemoryRegionByName("LK DTB")`，改名不匹配会静默返回
  `EFI_INVALID_PARAMETER`，DxeCore 打印 "Image ... start failed"）。
- 内存表：帧缓冲 carveout `0xFD91F000+0x26E0000`（LK 的 atag,videolfb）；
  驱动要探测的 MMIO：MMSYS 0x14000000 / MUTEX 0x14001000,0x14201000 /
  OVLSYS0 0x14400000 / OVLSYS1 0x14600000 / DISPSYS1 0x14200000 / DSC0 0x14206000 /
  DSI0 0x1420A000 / MIPI TX0 0x11E90000。
- rothko 全屏扫描层（内核 mtkfb.txt 实锤）：addr=FB 基址、pitch=4992(1248px)、
  size=1220|2712<<16、CFMT=RGBA。dali 的 PITCH_MSB/RDMA/CLIP/DATAPATH 等判据在
  MT6989 上语义不同，会把图层全否掉 → 已降级为告警。
- 推帧链：继承 LK 的 OVL→DSC→DSI→MUTEX，只写 DSI_START 0→1 + mutex，不碰 DSC/MMSYS。

## 显示实测结论（2026-11-02 亮屏）
- 实锤：`soft=00000004` → 唯一被降级的软判据是 **PITCH_MSB 的 bit20**（MT6989 另有用途，
  dali 规则会误杀）。RDMA_CTRL=0x1、OFFSET/CLIP/DATAPATH_EXT/CLRFMT_EXT 全 0，本来都能过。
- 扫描层共 2 个：L0=帧缓冲(pitch 4992/1248px, addr=FB 基址)、L1=LK 的 UI 层(pitch 4880)。
  顶部花屏=两个扫描层叠加（GOP 内容与 LK 的 logo/UI 同时在扫）+ pitch 1248 与 1220 不匹配。
- 推帧成功：mutex bank0 mod0=0x5080B735（含 DSI0 位），banks=7，
  `frame 1/2 submitted, dsi status=800A0004/800B0016` → DSI 命令模式触发链正常。
