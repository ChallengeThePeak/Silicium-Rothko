# K70U 带 pstore 日志的 UEFI 构建（2026-11-02）

上游源码：`ChallengeThePeak/Silicium-Rothko` `uefi/rothko` @ `3b336382d620adecade8d4b2110e8b8b7db496e9`
UniXNU：`67df14de69ae6f6ffc3480b30b70ce7667a3bd32`（worktree，用户原检出未被改动）
构建方式：上游官方 `DeviceBuild.py` + `stuart`（未使用旁路编译）

## 1. 产物

| 文件 | 大小 | SHA-256 |
| --- | ---: | --- |
| `bringup/SILICIUM_UEFI-pstore-20261102.fd` | 2097152 | `b4dc51d1975e9d343ce449875bb046c52ccb66059544b9162cacd52408d758eb` |
| `bringup/boot-k70u-uefi-pstore-20261102.img` | 67108864 | `e98479037e7215c45dca96e14484db1c22ea6dcd8ba292591de78f9d7fc82459` |
| `bringup/init_boot-k70u-uefi-pstore-20261102.img` | 8388608 | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/boot-k70u-uefi-pstore-20261102.report.json` | 1060 | `83da9c5d1a14f92e977a19082c65690b8732a890b22c3628fb049f3de29c046c` |

## 2. 构建链路（全部按上游文档）

1. `python Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --setup / --update`
   - 外部依赖 `Mu-Basetools v2026080000.0.0-rc0`、`OneCrypto 1.1.2`、`mu_nasm 20016.1.1` 全部就位
   - `mu_nasm` 由用户代下，放入 `~/.nuget/packages/mu_nasm/20016.1.1/` 后 `stuart` 走本地缓存命中
2. `DeviceBuild.py TARGET=DEBUG ENABLE_SECUREBOOT=0 FD_BASE=0x40400000 FD_SIZE=0x200000 FD_BLOCKS=0x200 DEVICE_MODEL=0 DISABLE_DEBUG_MACRO_CHECK=TRUE`
   - 结果：`PROGRESS - Success`，`FVMAIN [99%Full] 0x3d9000`，`FVMAIN_COMPACT [20%Full] 0x200000`
3. `tools/boot_v4.py --kernel-compression lz4 --preserve-avb-tail`

## 3. 离线校验结果（实测）

- FD 内含 `K70U_UEFI_PSTORE_BEGIN`、`SEC: loading DXE core`、`Loading DxeCore` 字符串
- `boot` 的 kernel 字段解压后 = 192 字节 BootShim + 2097152 字节 FD，**尾段与编译产物逐字节一致**
- ARM64 Image 头：`text_offset=0`、`flags=0xA`（上游归一化后的正确值）
- AVB 尾部：`0xf8b000` 起与模板**逐字节一致**，末尾 `AVBf` 存在；`avb_payload_resigned=false`
- `init_boot`：ramdisk 为 1 MiB FAT12，`vendor_ramdisk_prefix_bytes=0x270526a`

## 4. 对上游代码的唯一改动（必须记录）

`Platforms/Xiaomi/rothkoPkg/UniXNUConfig.dsc.inc` 里两条 PCD 被注释掉：

```
gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskOffset|0x02719743
gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskSize|0x00100000
```

原因（实测）：这两个 PCD **在 UniXNU 任何 DEC 中都未声明**（含最新提交 `a4419c8`），
且 `UniXNURamDiskDxe` 源码里也没有引用它们。
EDK2 报 `error F001: Pcd ... defined in DSC is not declared in DEC files`，属构建阻断。
注释后编译通过。原文件已备份到 `/home/ubuntu/quarantine/`。
**副作用**：`UniXNURamDiskDxe` 的 FAT 发布功能实际不可配置；对 pstore 日志测试无影响
（日志来自 `Sec.c` 的 `PstoreLogBegin`，且固件在 BCD/DXE 早期即停在 GCD 断言）。

其它处理：
- 用户 `~/UniXNU` 检出被切到 `67df14de`（可 `git checkout fb2bb31` 回退，reflog 保留）
- 我先前在 `uefi-full/` 下建的 `UniXNU` 软链已移到 `~/quarantine/`，避免包路径歧义
- mono 6.8 为本地解包安装（无 root），`MONO_CFG_DIR=/home/ubuntu/mono/etc`

## 5. 模板版本说明（重要限制）

打包模板用的是本机唯一完整的原厂包 **OS1.0.22.0 / Android 14**
（`Downloads/rothko_images_OS1.0.22.0.UNNCNXM_.../images`），
不是设备当前运行的 OS3.0.303。因此：

- `boot` 的 v4 头（命令行、os_version）与 AVB 尾部来自 1.0.22
- `vendor_ramdisk_prefix_bytes` 实测 `0x270526a`，与上游按 3.0.303 记录的 `0x02719743` 不同
  （因为 `vendor_boot` 版本不同；本次 PCD 已注释，不影响早期日志）
- 之前实机验证过 LK 能加载同一模板族构建的候选，故沿用

## 6. 刷写建议（未执行，需用户授权）

只刷 `boot`，保留现有 `init_boot`（stock CPIO 合法）：

```
fastboot flash boot boot-k70u-uefi-pstore-20261102.img
fastboot reboot
```

**刷前必须先备份当前 boot**（设备是 3.0.303，本机没有它的原厂 boot.img）：

```
adb shell su -c "dd if=/dev/block/by-name/boot_a of=/sdcard/boot_a_stock.img"
adb pull /sdcard/boot_a_stock.img
```

预期：黑屏 → 约数十秒后看门狗复位或停在断言。
恢复：`fastboot flash boot boot_a_stock.img`，进系统后读日志：

```
adb shell su -c "cat /sys/fs/pstore/pmsg-ramoops-0"
```

## 7. 未做的事

- 没有刷写、擦除、重启或改动任何分区
- 没有对 `init_boot` 做设备写入
- 本镜像**未在设备上验证**
