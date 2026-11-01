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
