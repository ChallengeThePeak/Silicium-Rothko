# BdsDxe HII 断言与调度顺序修复（2026-11-02）

## 1. 实机进展

上一版（fbfix）已越过 `Gcd.c`，DXE 成功装载了一批驱动：

```
Loading driver ... PcdDxe.efi
Loading driver ... RuntimeDxe.efi
Loading driver ... ArmCpuDxe.efi
Loading driver ... ArmGicDxe.efi
Loading driver ... MetronomeDxe.efi
Loading driver ... ArmTimerDxe.efi
Loading driver ... DiskIoDxe.efi
Loading driver ... PartitionDxe.efi
Loading driver ... Fat.efi
Loading driver ... EnglishDxe.efi
Loading driver ... VariableRuntimeDxe.efi
Loading driver ... UniXNURamDiskDxe.efi
UNIXNURAMDISK: device tree at 0x47C80000, 545359 bytes
UNIXNURAMDISK: initrd 0x66F00000-0x6A404188 is not a whole number of sectors
Loading driver ... BdsDxe.efi
ASSERT_EFI_ERROR (Status = Not Found)
ASSERT [BdsDxe] UefiHiiServicesLib.c(82)
```

## 2. 根因

`APRIORI.inc` 把 `BdsDxe` 排在**最后一条**。EDK2 的 APRIORI 驱动会**先于所有其他驱动**被调度，
所以 BdsDxe 在 `HiiDatabaseDxe` 之前就跑了。

而 `BdsDxe.inf` 的 Depex 是 `TRUE`，`HiiDatabaseDxe.inf` 也是 `TRUE`——
两者没有先后约束，唯一保证顺序的机制就是 FV 文件顺序。
`UefiHiiServicesLib` 的构造函数在 `UefiHiiServicesLib.c` 里 `LocateProtocol (gEfiHiiDatabaseProtocolGuid)`
失败 → `ASSERT_EFI_ERROR`。

实测确认 `HiiDatabaseDxe` **确实在 FV 内**（`Build/rothkoPkg/DEBUG_CLANGDWARF/FV/Guid.xref`
含 `348C4D62-BFBD-4882-9ECE-C80BB1C4783B HiiDatabase`），不是缺件，纯粹是顺序问题。

## 3. 修复

`Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc`：注释掉 BdsDxe 一条。

BdsDxe 回到 FV 顺序调度，而 `DXE.inc` 里 `HiiDatabaseDxe`（第 25 行）在
`BdsDxe`（第 30 行）之前，因此 HII 协议先就绪。
这也与 EDK2 官方平台的惯例一致：APRIORI 只放核心服务，BDS 不进去。

原文件备份：`/home/ubuntu/quarantine/APRIORI.inc.orig-*`。

## 4. 顺带发现：RamDisk 未发布（不阻断启动）

```
UNIXNURAMDISK: initrd 0x66F00000-0x6A404188 is not a whole number of sectors
```

LK 交过来的 initrd 总长度不是 512 的整数倍，`UniXNURamDiskDxe` 直接拒绝发布磁盘。
原因是本机打包模板是 **OS1.0.22**，而设备在跑 **OS3.0.303**，
`vendor_boot` 的 ramdisk 长度不同，上游记录的 `0x02719743` 也对不上（实测 `0x270526a`）。

影响：BDS 起来后不会看到 FAT 启动项。对"看固件能走多远"无影响，
后面要让 XNU 真正加载时需要处理（用设备实际版本的 `vendor_boot` 重新打包，
并让驱动改为向下取整到扇区而不是直接放弃）。

## 5. 本版镜像

| 文件 | 大小 | SHA-256 |
| --- | ---: | --- |
| `bringup/boot-k70u-uefi-pstore-bdsfix-20261102.img` | 67108864 | `c0110a83672541eb1a39d40ebb3e869b199c0d2141d31436b419881a0e97e9bd` |
| `bringup/init_boot-k70u-uefi-pstore-bdsfix-20261102.img` | 8388608 | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/SILICIUM_UEFI-pstore-bdsfix-20261102.fd` | 2097152 | `0062218148f1bf3108706d5a4c3dfb8a3f22dc662ee3edf3ed4aa44a59db1e77` |

## 6. 下一轮判据

- 若越过 `BdsDxe` 且无 HII 断言 → BDS 起来了，观察是否有新的断言或停在菜单/空闲；
- 若换新模块断言 → 用 `llvm-symbolizer` 解析该模块 RVA，继续同类修复；
- 若停在 BDS 且无磁盘 → 属预期，下一步换成设备实际版本的 `vendor_boot` 重新打包。
