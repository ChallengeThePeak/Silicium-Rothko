# Redmi K70 Ultra (rothko / MT6989) UniXNU Adaptation

Status: host-side feasibility review with an unintegrated v4 image utility.
No firmware image was modified and no device was flashed.

## Current UniXNU Integration Model

The checked-out UniXNU main repository is at
`67df14de69ae6f6ffc3480b30b70ce7667a3bd32` (2026-10-31) and uses device
repository Format 2. Its porting guide separates board integration
(`UniXNU-rothko`), reusable SoC support (`UniXNU-mt6989-common`), reusable
drivers/components, and platform firmware (`uefi-rothko`). The in-tree
`examples/device` is an SM8550 template, not a K70U package. The main
repository's `devices.toml` currently has no Rothko/MT6989 entry.

Treat `K70U-PORT` as the investigation and integration workspace, not as a
finished Format 2 device repository. Before invoking UniXNU's device build
commands, create a dedicated device-repository root from `examples/device`
and replace its inherited SM8550 configuration only with reviewed MT6989
inputs. Keep the Android boot-image packer and stock-image evidence alongside
that repository, but do not copy the example's zero memory range, component
set, kernel config, or firmware paths as if they were K70U values. The
existing MT6789 `stonePkg` is useful only as an EDK II structure example.

For the first XNU baseline, use UniXNU's existing
`ipados-17.7.11-21H461` profile unless a different iPadOS target is required.
It pins the donor OS/XNU ABI inputs (iPad7,1, XNU 10063.141.1); it is separate
from K70U's Android 3.0.303 boot stack and does not make the donor's hardware
description a K70U description.

## Feasibility By Milestone

This assessment separates a UEFI/XNU proof from a usable iPadOS system:

| Milestone | Current outlook | Evidence and gap |
| --- | --- | --- |
| Pack and enter UEFI | Direct v4 UEFI is the first bounded experiment; unverified | The stock LK image is v4. First test one minimal direct BootShim/UEFI handoff using a small `init_boot` FAT. If it reaches firmware, measure the full payload and test a RAM-backed normal `vendor_boot` FAT before implementing UEFI UFS. If that FAT cannot fit, evaluate a UEFI UFS restart; Linux-preboot remains a fallback requiring exact kernel/jump inputs. No EDK FD or K70U handoff is verified. |
| XNU CPU/platform entry | Plausible, unverified | The stock FDT describes eight AArch64 CPUs and PSCI SMC. MTK GIC setup, timer state, memory map and XNU ADT still need target evidence. |
| Displayed UEFI/menu | Plausible with inherited scanout | Root ADB confirms the selected `n12_42_02_0a_dsc_cmd` panel and 1220x2712 DRM mode; LK exports a framebuffer candidate. GOP stride/pixel format, physical page runs, cache attributes and scanout continuity into UEFI remain unverified. |
| Persistent iPadOS root | Major blocker, with target-specific firmware source | The stock FDT and Xiaomi Linux source provide matching MediaTek UFSHCI/PHY references; local recovered MT6989 LK also contains a working one-slot UFS host implementation and its link-start sequence. The recovered original `platform_pre_chain_load()` is empty; `platform_quiesce()` then calls `ufs_deinit()` before chain-load, so UEFI must not assume UFS is live. A RAM-backed vendor-ramdisk FAT may carry the first full payload without UEFI UFS; XNU still needs its own native UFS/root path. |
| Native GPU/Metal UI | High-risk, with a reusable software-stack precedent | K70U's MT6989/Dimensity 9300+ uses Immortalis-G720 MC12; the stock FDT exposes a Mali/Valhall-compatible node at `0x13000000`. UniXNU's RK3588 EVB10 record device-verifies Mali-G610 CSF with MaliMetal/PanVK, so Mali is not an unsupported family in general. G720 is a different GPU generation and K70U has a different MediaTek GPUEB, SMMUv700, clock/power and firmware path. Reuse the Mali frontend only after the target kernel driver, firmware ABI, DMA ownership and G720 backend are qualified; never select Adreno components. |
| Touch, Wi-Fi, audio, power | Unknown/high effort | The DTB contains board-specific SPI touch and multiple WLAN descriptions, but the active IC variants, firmware, power sequencing and UniXNU/XNU driver interfaces are not yet established. |

Therefore, UEFI and an early XNU entry are credible engineering targets, but
they do not establish full iPadOS usability. Native UFS/root and a Mali graphics
path are the largest product-level gaps; track them as separate gates rather
than declaring success at the UniXNU menu or XNU entry.

## Decision

The host-side packaging baseline is a **stock-layout Android boot v4 pair**:
`boot` carries UniXNU's BootShim/UEFI in the kernel field and `init_boot`
carries a small raw FAT ramdisk. Keep the matching stock `vendor_boot` and
`dtbo` unchanged. This preserves the header version already used by the
device and exercises the recovered v4 path that uses the vendor DTB and
external `dtbo`. A device-scoped `UniXNURamDiskDxe` offset must skip the
normal-boot vendor ramdisk prefix before publishing the FAT block device.
This pair is the low-risk menu/firmware test, not the final payload layout:
the 8 MiB `init_boot` cannot hold the full XNU payload, and recovered LK
quiesces UFS before direct UEFI.

Use the stock LK as the first-stage loader. Keep `vendor_boot`, `dtbo`, `lk`,
`preloader`, and all other partitions unchanged. The initial experiment
changes only `boot` and `init_boot`; preserve both stock images for restore.
Write to the actual active-slot partition names and enter through a normal
reboot into LK; no `fastboot boot` path is assumed or needed.
For initial host validation, omit a full XNU payload and use a small,
non-empty raw FAT ramdisk in `init_boot` to bring up only the UEFI/UniXNU menu.
The original `init_boot` is compressed CPIO and is not the test disk. Do not
use a zero-byte ramdisk: the recovered LK path requires a nonzero ramdisk
target.

For the first XNU payload, measure the complete UniXNU FAT output before
implementing UEFI UFS. The preferred no-UEFI-storage candidate is a derived
`vendor_boot_b` whose normal type-1 ramdisk is a raw FAT carrying
`unixnu.toml`, `kernel.macho`, its ADT, and trust cache. The current normal
ramdisk is 40,998,723 bytes; removing the recovery type-2 entry would let the
normal FAT use most of the current 54,917,581-byte aggregate ramdisk budget,
subject to the actual LK `mb_ramdisk` size and the 64 MiB partition bound.
UEFI would publish only offset 0 and the exact FAT length from the LK-loaded
initrd. Keep the stock B images and the complete A slot untouched as rollback.
If the measured payload does not fit this RAM-backed volume, use an external
raw FAT partition only after UEFI UFS reads are qualified; do not assume
encrypted userdata is available before Android.

This is a candidate packaging plan, not a bootability claim. The LK source in
this workspace is a partial reconstruction and has not been validated on this
device. A separate MTK port (MT6833 Camellia) reports that direct LK-to-
BootShim/UEFI reset and that its device-verified route instead jumps from a
minimal Linux initramfs. Treat direct boot as a diagnostic experiment, not a
presumed successful handoff; see the route decision below.

## Evidence From This Checkout

| Input | Finding |
| --- | --- |
| `boot.img` | 64 MiB, Android boot header v4, kernel size 16,547,799 bytes, ramdisk size 0. The kernel field begins with legacy LZ4 magic `02 21 4c 18`. Its embedded `com.android.build.boot.fingerprint` is `Xiaomi/hal_mgvi_64_armv82_mt6989_cn/mgvi_64_armv82:14/UP1A.231005.007/OS3.0.303.0.WNNCNXM:user/release-keys`. |
| `vendor_boot.img` | 64 MiB, header v4, page size 4096, total vendor ramdisk size 54,917,581 bytes, two 108-byte table entries, DTB size 444,690 bytes. Type 1 (normal boot) is 40,998,723 bytes at offset 0; type 2 (`recovery`) is 13,918,858 bytes at offset 40,998,723. The recovered LK selects type 1 for normal boot and selects type 2 only in recovery mode. |
| `init_boot.img` | User-provided `C:\Users\24718\Desktop\output\init_boot.img`, 8 MiB, Android boot header v4, generic ramdisk size 3,132,721 bytes. It is an LZ4 legacy frame (`02 21 4c 18`) containing a `070701` CPIO archive; host decompression yielded 5,830,912 bytes. Its embedded `com.android.build.init_boot.fingerprint` matches `boot.img`; security-patch metadata is `2026-02-01`. |
| Build coherence | `boot.img`, `vendor_boot.img`, `dtbo.img`, and the supplied `init_boot.img` all contain the same `OS3.0.303.0.WNNCNXM:user/release-keys` fingerprint. They are positively identified as the same 3.0.303 build, not matched by filesystem timestamps. |
| Bootloader/OS combination (owner-confirmed) | The device intentionally runs LK 2.0.202 with OS 3.0.303. The owner reports this combination has been used without issues; LK 3.0 is avoided because it burns/invalidates the owner's DA version. Treat this as device-verified Android boot compatibility, not as a version mismatch or adaptation risk. The UniXNU iPadOS donor/profile version is a separate choice from Android OS 3.0.303. Custom LK-to-UEFI handoff state still needs its own qualification. |
| Bootloader unlock (owner-confirmed) | The bootloader is unlocked and the owner confirms boot partitions can be modified. Use a normal LK boot after writing only the backed-up target partition(s); do not use or require `fastboot boot`, which is unavailable on this MediaTek device. This does not establish that the alternate v2 Android header layout is accepted. |
| Live device boot (root ADB, 2026-10-31) | Device `rothko`, SoC `MT6989`, active slot `_b`, OS fingerprint `Redmi/rothko/rothko:16/.../OS3.0.303.0.WNNCNXM`, kernel `6.1.138-android14-11-g6ab8c9a86a33-ab14396278`. Active `boot_b` and `vendor_boot_b` are each 64 MiB; `init_boot_b` and `dtbo_b` are each 8 MiB. Root ADB was read-only; no device data or partitions were changed. |
| Live UFS/GPT (root ADB, 2026-10-31) | SCSI host `host0` reports `ufshcd`; LU `sdc` reports Micron `MT256GBEAX4U40`, revision `0205`, 4096-byte logical blocks and 264,509,587,456 bytes capacity. `userdata` (`sdc91`) starts at 512-byte sector 23,709,696 and spans 492,877,760 sectors (252,353,413,120 bytes); Android reports file-based encryption. Do not treat userdata as a pre-Android payload filesystem. |
| K70U v4 host utility | `K70U-PORT/tools/boot_v4.py` builds v4 `boot` and `init_boot` images from read-only stock templates, keeps `signature_size=0`, pads to template partition sizes, validates the gzip/FAT payloads, and derives the normal vendor-ramdisk size from the v4 table. It can compile UniXNU's BootShim around a supplied EDK FD using an explicit `FD_BASE`, or accept a prebuilt gzip kernel. The FD path rejects non-identical copy ranges that overlap the executing/decompressed source, requires FD size to be a multiple of BootShim's 16-byte copy granularity, and reports the `kernel_addr` read from `vendor_boot`. Seven synthetic unit tests pass, and an end-to-end temporary pack using the actual 3.0.303 stock templates produced correctly sized 64 MiB/8 MiB images with `signature_size=0`; the actual vendor ramdisk prefix parsed as `40,998,723` bytes (`0x02719743`). This used synthetic payloads only: the tool is not integrated with the EDK firmware build and no real FD/FAT pair has been packaged. A WSL assembly of the current BootShim with the ARM64 header places `_Payload` at offset `0xC0`; for a `0x40000000` kernel target, the in-place FD base would be unaligned `0x400000C0`. With a diagnostic `0x200000` FD size, `0x40400000` is geometrically disjoint from the loaded source while `0x40200000` partially overlaps it. These are copy-range results only; neither FD size nor destination has been qualified against LK mblocks. |
| `vendor_boot` address fields | `kernel_addr=0x40000000`, `ramdisk_addr=0x66f00000`, `tags_addr=0x47c80000`, `dtb_addr=0x47c80000`. |
| Vendor DTB and runtime mblock | A 64-byte MediaTek wrapper precedes the stock FDT. Root ADB captured the live FDT with `/memory@40000000/reg = <0x40000000 0x300000000>` and the LK `mblock_info` property (22,552 bytes, version 2): 31 free extents and 58 reserved records. All 58 reserved ranges exactly match the LK-generated `/reserved-memory/mblock-*` nodes. This is the first target-derived allocator snapshot, not a ready UEFI map: recovered `linux_boot.c` frees the kernel, DTB and initrd mblocks before exporting `mblock_info`, so those boot handoff ranges must be reserved separately. The 12 GiB outer extent also contains reserved ranges and must not be advertised wholesale as usable RAM. |
| `dtbo.img` | The Android DT table has one entry (ID 0); its payload is 114,397 bytes and fits LK's 1 MiB load buffer. Extracting the FDT after the 64-byte MediaTek wrapper and applying this entry with `fdtoverlay` succeeds; the merged DTB grows from 444,626 to 517,489 bytes. The decoded result is retained at `K70U-PORT/board/rothko/OS3.0.303-stock-merged.dts`. It contains DSI0 candidates `n12_42_02_0a_dsc_cmd` at `panel1@0` and `n12_36_02_0b_dsc_cmd` at `panel2@1`. Root ADB's live `/chosen/atag,videolfb` names `n12_42_02_0a_dsc_cmd_lcm_drv`, and live kernel arguments select the same panel driver; this confirms the fitted/selected primary panel is the `panel1@0` candidate. |
| Stock FDT platform facts | Root compatible identifies MT6989. It describes 8 CPU nodes (MPIDR affinities 0x0-0x3, 0x100-0x102, 0x200) with PSCI `arm,psci-1.0` using SMC; MTK GIC nodes at `0x0c000000` and `0x0c400000`; UFS HCI `mediatek,mt8183-ufshci` at `0x112b0000` and PHY `mediatek,mt8183-ufsphy` at `0x112a0000`; and DSI0 at `0x1420a000` enabled while DSI1 at `0x1420b000` is disabled in the base tree. These are FDT-described resources, not yet validated register ownership or driver-ready settings. |
| UFS platform resource inventory | In the merged stock tree, UFSHCI is `0x112b0000..0x112b29ff`; MPHY is `0x112a0000..0x112affff`; HCI clock names include `ufs_sel`, `ufs_fde`, UniPro and HCI/AES clocks; reset names are `unipro_rst`, `crypto_rst`, `hci_rst`; and the node references `dvfsrc-vcore-supply` and `vcc-supply`. `drivers/ufs/host/ufs-mediatek.c` and `drivers/phy/mediatek/phy-mtk-ufs.c` at Xiaomi source commit `197c453d27da88f3b7b8fed7323ee6d15fc02066` match these exact generic compatible strings. This is a Linux reference for resource ordering and UIC/PHY behavior, not a K70U-qualified EDK/XNU driver or proof that all runtime clocks/resets can be reinitialized after LK. |
| LK runtime handoff | Root ADB reads the live LK handoff FDT: initrd range `0x66f00000..0x6a6d3adc` (58,538,716 bytes); `/proc/iomem` marks its page-aligned envelope reserved. The `atag,videolfb` fields report base `0xfd91f000`, VRAM reservation `0x026e0000` (40,763,392 bytes), and panel name `n12_42_02_0a_dsc_cmd_lcm_drv`; DRM exposes `1220x2712` modes. Panel identity and the mblock snapshot are confirmed, but scanout continuity into UEFI, stride/pixel format, cache attributes and GOP page-map behavior are not. For v4, LK's reported initrd size includes both vendor ramdisk table entries, while normal mode copies only type 1 before `init_boot`; bootconfig follows the larger reported total. Therefore the FDT range is an envelope, not a contiguous disk. `UniXNURamDiskDxe` must expose only the exact FAT subrange with board-scoped offset/size, never the whole FDT range. |
| Local partition inputs | `boot.img`, `vendor_boot.img`, and `dtbo.img` are in the workspace; the matching `init_boot.img` is outside it at the path above. No local partition image was modified. |
| Kernel source availability | The checked Xiaomi [`bsp-rothko-u-oss`](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/bsp-rothko-u-oss) branch resolves to `197c453d27da88f3b7b8fed7323ee6d15fc02066` (2024-10-10). Its MediaTek DTS directory has 92 entries and no `rothko`/`MT6989`-named file. The public [`rothko_kernel_mt6989` Android-U mirror](https://github.com/ryzongt/rothko_kernel_mt6989/tree/Android-U) was also checked; its MediaTek DTS directory has 92 entries and no target-named DTS. These trees are kernel sources, not a ready K70U board DTS package. |
| Local stock-kernel evidence | `re/charge_thermal/device_20261013_014221/state.txt` records OS `OS3.0.303.0.WNNCNXM` and Linux `6.1.138-android14-11-g6ab8c9a86a33-ab14396278`; the local `vmlinux` contains the same release string. A top-level `Module.symvers` is present, but its provenance against the supplied `boot.img` is not established. `re/gz/upstream/rothko-kernel-interface` is only a partial interface tree, not a complete kernel Kbuild/header tree. Do not claim a matching jump module can be built from these artifacts alone. |
| UniXNU repository model | The local main checkout is Format 2 at `67df14de69ae6f6ffc3480b30b70ce7667a3bd32` (2026-10-31). `examples/device` requires a separately resolved board repository with `board.toml`, `feeds.toml`, kernel config, DTS, `porting.toml`, and pinned source revisions; the guide separates this from SoC-common support and the device UEFI repository. `devices.toml` has no Rothko/MT6989 entry. Start a `UniXNU-rothko` device repository and `uefi-rothko` platform from the current format, and create/pin MT6989 common support only after its inputs and ownership are reviewed. Do not retrofit the old generic `bootimg.py` path or treat the example SM8550 template as target-ready. |
| UFS source availability | The stock FDT identifies MT6989 UFSHCI/PHY, clocks, resets, regulators and interrupts. At Xiaomi source commit `197c453d27da88f3b7b8fed7323ee6d15fc02066`, Linux `ufs-mediatek.c` matches `mediatek,mt8183-ufshci` and `phy-mtk-ufs.c` matches `mediatek,mt8183-ufsphy`, exactly as in the merged K70U DTB. Root ADB confirms the running 6.1.138 kernel has SCSI host `ufshcd`, Micron LU `sdc`, and the command-line flag `initcall_blacklist=ufshcd_core_init`; therefore that flag does not prevent the MTK host and UFS storage from operating on Android. It says nothing about whether LK's later `ufs_deinit()` leaves a live link. Linux remains the best clock/PHY reference, not an EDK II or XNU driver. EDK II `UfsPassThruDxe` requires a K70U host-controller producer; UniXNU's documented `ShengUfs` targets SM8550. |
| Recovered LK v2 path | Reads the base DTB after the kernel, ramdisk, and aligned recovery-DTBO payloads; strips the MediaTek DTB wrapper; loads and applies the regular `dtbo` partition in normal boot; then runs `platform_choose_dtb`. Kernel, tags, and ramdisk targets are checked against named mblocks. |
| Recovered LK ramdisk selection | For header v2, `get_ramdisk_addr()` points into `boot`, `get_ramdisk_total_real_sz()` excludes `vendor_boot`, and `linux_boot.c` does not prepend a vendor ramdisk. The v2 initrd therefore starts at the test ramdisk bytes. For v4, LK copies the selected type-1 vendor ramdisk before the `init_boot` ramdisk. |
| Recovered LK v0/v1 path | `decompress_kernel` accepts legacy LZ4 and gzip. This path scans for an appended FDT in the last 512 KiB, requires the kernel address to be 512 KiB aligned, and does not enter the v2/v3/v4 DTBO-loading branch. |
| Recovered v4 path | Header v4 requires both `vendor_boot` and `init_boot`. The v4 kernel target and tags target are read from `vendor_boot`; the generic ramdisk comes from `init_boot`. |
| Recovery confidence | The LK project is ET_REL, roughly 70% source-associated by its own metric, and explicitly not a flashable LK or real-hardware validation. |

The stock FDT was parsed from the local `vendor_boot.img`; it is a useful
board-resource baseline. Its memory and reserved-memory declarations are not
the LK runtime allocation map. The three `vendor_boot` address fields are
strong candidates for matching LK reservations because the recovered path
compares the kernel, tags, and ramdisk targets to named mblock starts. Treat
them as inferred until confirmed by a stock LK log or equivalent target
evidence.

Relevant local sources:

- `boot.img`, `vendor_boot.img`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/app/mt_boot/boot_info.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/app/mt_boot/linux_boot.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/app/mt_boot/decompress.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/app/mt_boot/avb/load_vfy_boot.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/dev/display/fdt_export.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/dev/display/panel_probe.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/dev/ufs/init.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/dev/ufs/controller.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/recovered/app/mt_boot/fdt_registry.c`
- `LK_RECOVERY/project/mt6989_lk_recovery/HANDOFF.md`
- `K70U-PORT/uefi-mtk-reference/Silicon/Silicium/SiliciumPkg/Sec/Sec.c`
- `K70U-PORT/uefi-mtk-reference/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c`
- `K70U-PORT/uefi-mtk-reference/Platforms/Xiaomi/stonePkg/Library/MemoryMapLib/MemoryMapLib.c` (architecture example only; not a K70U map)
- `K70U-PORT/uefi-mtk-reference/Mu_Basecore/MdeModulePkg/Bus/Ufs/UfsPassThruDxe/UfsPassThruHci.c`
- `K70U-PORT/uefi-mtk-reference/Mu_Basecore/MdeModulePkg/Include/Protocol/UfsHostControllerPlatform.h`
- `K70U-PORT/uefi-mtk-reference/Mu_Basecore/MdeModulePkg/Include/Protocol/UfsHostController.h`

External implementation references:

- [UniXNU generic boot-image builder](https://github.com/UniXNU/UniXNU/blob/main/scripts/unixnu/bootimg.py) and [MT6833 Camellia bring-up record](https://github.com/UniXNU/UniXNU/blob/main/docs/zh/devices/camellia.md).
- [Mu-Silicium AOSP-derived `mkbootimg.py`](https://github.com/Project-Silicium/Mu-Silicium/blob/main/Resources/Scripts/mkbootimg.py).
- [EDK II generic `UfsPassThruDxe`](https://github.com/tianocore/edk2/tree/master/MdeModulePkg/Bus/Ufs/UfsPassThruDxe), which consumes the host-controller protocol and initializes UFS; it is a protocol-layer reference, not MT6989 PHY/platform support.

## UFS Handoff And Bring-Up

An inherited-live-link EDK II path is **not the plan**. UEFI UFS is not needed
for the menu, and the first full-payload candidate is a FAT carried in LK's
normal vendor ramdisk so it is already in RAM. Implement a UEFI UFS host only
if the measured payload cannot fit that bounded RAM volume or an external
pre-boot source is required. The owner-confirmed working stock combination
is LK 2.0.202 with OS 3.0.303; there is no LK/OS
version-compatibility concern here. In the recovered MT6989 LK sources,
`linux_boot.c` enters `platform_chain_load()`;
`chain_load.c` calls `platform_quiesce()` before the architectural handoff;
and `platform.c` calls `ufs_deinit()` from `platform_quiesce()`.
`ufs_deinit()` sends UFS poweroff notification, resets the device, and clears
HCI registers at offsets `0x18` and `0x34`. Taken at face value, a direct
LK-to-UEFI chain-load arrives after storage teardown. This concerns the
custom payload handoff state, not the already-proven Android boot combination.
The recovered `platform_pre_chain_load()` is explicitly an empty original
hook; the resulting post-quiesce UFS state still needs qualification.

There is a useful target-specific restart reference rather than a generic
inherited-link assumption: local recovered LK implements `ufs_init()` and
`ufshcd_init()`, including HCI re-enable, MTK pre-link DME settings, UIC link
startup, device initialization, and block reads. It uses one transfer slot,
allocates command/transfer buffers with 128/64-byte alignment, and records
HCI `0x112b0000`, PHY `0x112a0000`, and PeriCFG `0x112bd000`. Its
`ufs_init_mphy()` body is empty, and the visible UFS init does not show
Linux-style regulator/clock-provider bring-up. LK initializes UFS earlier in
`platform_init()`; `ufs_deinit()` does not visibly gate named clocks or power
domains. This makes a **UEFI link restart using retained platform resources**
a tractable fallback storage experiment, but it is not yet proven. The recovered
`platform_pre_chain_load()` is explicitly an empty original hook. Qualify
post-quiesce clock/PHY state and implement a bounded restart sequence before
selecting this as the payload storage path.

Keep the first UEFI storage milestone deliberately smaller than a full port:
serial-polled completion, one transfer slot, bounded waits, controller/link
restart, device descriptor and capacity reads, then read-only Block I/O and
GPT. Port only the needed target LK descriptor/query/SCSI read operations.
Replace LK allocation, MMU, event, interrupt, cache and secure-call assumptions
explicitly. Exclude RPMB, writes, erase, firmware update, write booster,
unbounded unit-ready retries, and LK partition mutation policy.

The LK command-line append of `initcall_blacklist=ufshcd_core_init` initially
looks like it might suppress UFS. In the checked Xiaomi Linux source revision,
however, `ufshcd_core_init()` only initializes debugfs and registers the SCSI
UFS-device-WLUN driver; the separate MediaTek platform driver registers its
own probe, and that probe calls `ufshcd_pltfrm_init()`. Thus blacklisting this
one core initcall does not by itself show that the MTK host controller/link
probe is skipped. Root ADB confirms the target command line contains the
blacklist while `host0` (`ufshcd`) and LU `sdc` are present, so normal Android
UFS initialization succeeds with it. This does not prove UFS survives LK's
later `ufs_deinit()` or identify the exact vendor kernel source revision.

EDK II `UfsPassThruDxe` is not a replacement for the MT6989 host provider.
Its v3 `EDKII_UFS_HC_PLATFORM_PROTOCOL` skip flags can avoid HCE re-enable and
UIC link startup, but the driver still initializes UTP request lists and needs
valid DMA/SMMU/cache handling. Use it only after implementing and qualifying
the MT6989 host operations; do not use skip flags to paper over LK's
`ufs_deinit()`.

If UEFI must read an external payload, first port and audit the local MT6989
LK controller,
UIC, descriptor/query and read-command paths into a bounded UEFI read-only
block provider. Replace LK allocation, MMU, event/IRQ, cache and SMC
assumptions with explicit UEFI implementations. EDK II `UfsPassThruDxe` is an
alternative protocol layer, not a drop-in driver: use it only after proving
its host protocol, UTP list ownership and DMA/SMMU behavior match the ported
host. If target evidence shows PHY/clocks need cold start, derive those steps
from the exact K70U DTB, Linux driver and hardware logs. Bring-up order:
post-quiesce register/clock snapshot, HCE, link startup, device
descriptor/query reads, bounded read-only block I/O, GPT, then XNU-native
storage. UEFI UFS and XNU UFS remain separate deliverables; neither the Linux
nor EDK protocol driver supplies XNU's `IOStorageFamily`/root mount path.

## Mali / Metal Candidate Path

MediaTek identifies the Dimensity 9300+'s GPU as Immortalis-G720 MC12
([official specifications](https://www.mediatek.com/products/smartphones/mediatek-dimensity-9300-plus)).
The K70U merged stock FDT has `mediatek,mali` / `arm,mali-valhall` at
`0x13000000`, with a `0x480000` register window, JOB/MMU/GPU/EVENT/PWR and
GPUEB mailbox interrupts, GPU OPP data, and MTK GPU-IOMMU nodes backed by
SMMUv700. These describe the hardware, not a ready-to-use Linux/XNU driver or
the correct stream/context setup.

UniXNU's RK3588 EVB10 record is a real reuse lead: Mali-G610 CSF, the
`package/Mali` driver, proprietary CSF firmware, MaliMetal, and PanVK have
device-verified iPadOS UI rendering. It is not evidence that this component
supports G720. The existing K70U FDT string `arm,mali-valhall` is too broad to
establish product ID, CSF ABI, firmware compatibility, or clock/power behavior.

Before enabling target GPU code, inventory the exact 3.0.303 vendor kbase
driver and CSF firmware version/hash, GPU product/revision registers, GPUEB
firmware and mailbox contract, power-domain/regulator/clock sequence, SMMUv700
stream IDs and context ownership, reserved/protected memory, and interrupt
topology. Compare those inputs with EVB10's Mali component and the selected
PanVK/Metal integration. First keep LK GOP as display and prove bounded GPU
register access, firmware boot, MMU/DMA, one command submission and a known
rendered image; only then attempt iOS Metal/UI. Do not start GPU work before
XNU entry, storage/root and basic framebuffer presentation are stable.

## Candidate v2 Image Parameters

For an initial host-side packer test, use the separate stock vendor DTB
payload (remove its 64-byte MediaTek wrapper) and test these candidate values
against AOSP `mkbootimg` output and the recovered LK parser:

```toml
[boot_image]
header_version = 2
base = 0
kernel_offset = 0x40000000
ramdisk_offset = 0x66f00000
tags_offset = 0x47c80000
dtb_offset = 0x47c80000
pagesize = 4096
```

These addresses are candidates, not confirmed mblock values. The kernel,
ramdisk, and tags addresses match the stock `vendor_boot` header and the
recovered LK's address-selection rules for headers <=2; `dtb_offset` is the
Android v2 DTB load-address field and should be kept consistent with the
candidate DTB address. The reconstructed LK checks `tags_addr` against
`mb_dtb` and `kernel_addr` against `mb_kernel`; obtain actual mblock evidence
before treating the values as valid.

Use a small, non-empty FAT ramdisk so the target has a nonzero ramdisk target
and UniXNURamDiskDxe can publish the initrd as a block device. v2's separate
DTB avoids the legacy appended-FDT scan limit; do not append the DTB to the
compressed kernel. Set `recovery_dtbo` empty/zero for this normal-boot test:
the recovered path loads the external `dtbo` partition by name. Validate the
one table entry and overlay application on the host, but do not guess which
panel fragment is active solely from its presence in the overlay.

UniXNU's existing `bootimg.py` emits a v0-style compressed kernel with an
appended tree, so it is not directly suitable as-is. A K70U-specific packer
or verified extension must write a v2 header, keep the DTB as a separate
payload after the recovery-DTBO slot, and verify the v2 header and payload
boundaries. The whole image must fit the 64 MiB `boot` partition.

Concretely, the current UniXNU builder has three v0 assumptions that need
targeted changes: its documented/default image header is v0; it passes the
tree only as bytes appended to the gzip stream; and its verifier expects
gzip's unused bytes to equal that appended tree. For a v2 implementation,
pass a separate DTB file and `--dtb_offset` to Mu-Silicium's `mkbootimg.py`,
include `dtb_offset` among accepted board configuration flags, and make the
verifier parse the v2 extension and payload order (kernel, ramdisk,
recovery_dtbo slot, DTB). Continue checking the gzip stream independently.
Do not change the generic builder defaults for other devices; add a device
configuration path and focused tests for v0 and v2 round-trips.

There are two different device-tree artifacts in this flow. The boot-image
DTB is the MediaTek/Linux FDT that LK overlays and passes to BootShim/UEFI.
The board DTS used by UniXNU's payload builder is converted to Apple's ADT
for XNU. They share hardware facts but are not interchangeable files. Keep
both as explicit, separately validated inputs.

## Boot Header Route Decision

Prefer v4 because all four supplied stock images are from the same v4
3.0.303 build and the recovered LK's normal v4 path explicitly loads
`vendor_boot` and `init_boot`. This avoids a header-version downgrade; it is
not a claim that modified images have been boot-tested. In normal boot LK
concatenates the type-1 vendor ramdisk (40,998,723 bytes, `0x02719743`) before
the generic `init_boot` ramdisk; the type-2 recovery ramdisk is excluded. A
v4 test can replace the generic ramdisk with raw FAT, then configure
`UniXNURamDiskDxe` to publish a bounded subrange beginning at
`linux,initrd-start + 0x02719743`. The shared driver now has fixed PCDs for
the byte offset and exact byte size, with both-zero defaults preserving the
old whole-initrd behavior. A K70U platform DSC still needs to set the offset
to `0x02719743` and the size to the exact sector-aligned FAT image length.
Do not derive disk length from `linux,initrd-end`: recovered LK computes the
v4 total using the complete vendor ramdisk size (normal plus recovery), but
normal-mode copy concatenates only type 1 before `init_boot`. Bootconfig is
placed after the larger reported total, so the FDT range can include a gap
between the copied FAT and bootconfig as well as the bootconfig trailer. Pass
both offset and exact FAT byte length as device-scoped fixed PCDs (or
equivalent board config); require a nonzero, 512-byte-aligned disk size, and
validate offset + size against the FDT initrd range before installing Block
I/O. Derive the prefix from the selected normal-boot vendor ramdisk table, not
from an unrelated property or universal constant. The current driver keeps
legacy whole-initrd behavior only when both PCDs are zero; the K70U platform
must set both. This changes `boot` and `init_boot`, while keeping the large
`vendor_boot` and `dtbo` images intact.

Keep v2 as an alternate experiment if preserving `init_boot` is more
important than preserving the stock header version. The recovered 3.0.303 LK
has a v2 parser/path, and v2 places the test FAT ramdisk directly at initrd
offset zero, but no real K70U test proves the unlocked boot chain accepts a
v2 image on this stock v4 layout. It also changes `boot` and needs a separate
boot DTB in the v2 image. v0 is a weaker fallback: it needs host-merging the
overlay into an appended DTB, retains 512 KiB alignment/scan limits, and
loses LK's normal external-DTBO path.

## Bring-Up Plan

1. **Freeze inputs.** Preserve stock `boot`, `vendor_boot`, `init_boot`,
   `dtbo`, `lk`, and `preloader`. Identify the active slot and exact partition
   names/sizes from the device's partition metadata; the local images alone do
   not establish A/B behavior.
2. **Prove the image format on the host.** Build a v4 `boot` image with the
   BootShim/UEFI kernel payload, and a v4 `init_boot` whose ramdisk is a small
   raw FAT image. Preserve required header fields/signature policy, verify
   kernel/ramdisk boundaries, fit within the actual partitions, validate the
   stock vendor DTB/DTBO inputs, and check BootShim's ARM64 Image header.
   Separately validate the calculated vendor-ramdisk prefix and DXE block
   offset. Both supplied stock v4 headers report `signature_size=0`; they are
   padded to their 64 MiB and 8 MiB partition sizes respectively. The local
   Mu-Silicium `mkbootimg.py` always sets the v4 header signature size to
   4096 and appends that area, even when no GKI signing key is supplied. AOSP's
   current writer only adds this GKI signature area when signing parameters
    are supplied; it is separate from device AVB/vbmeta. The owner confirms
    the bootloader is unlocked and boot partitions are modifiable, so AVB
    unlock is not a first-route gate. Do not use the local Mu writer unchanged:
    adapt it or use the AOSP-compatible
   signature policy, and assert the resulting `signature_size` and payload
    offsets against stock. Verify exact partition-size output. Reference:
   [AOSP mkbootimg.py](https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/main/mkbootimg.py).
   Keep a v2 packer/verifier path as a fallback, not the default.
3. **Resolve the DTBO.** The host-side extraction and `fdtoverlay` application
   of the sole stock entry now pass, and the merged tree is retained under
   `K70U-PORT/board/rothko/`. DTC reports vendor-tree schema/style warnings,
   but the DTB parses, overlay fixups resolve, and the merged output converts
   back to DTB. This proves host format compatibility, not that LK's
   `platform_choose_dtb` chooses the same result or that a panel is identified.
   Use the runtime LK log/FDT to establish the selected panel before enabling
   a panel-specific driver; the overlay itself contains both candidates.
4. **Audit BootShim memory use.** `BootShim.S` sets the FD source to `_Payload`,
   compares it with `FD_BASE`, and skips copying only when they are identical.
   Otherwise it performs a forward 16-byte copy without a general overlapping-
   range check. A useful *candidate*, not a chosen address, is therefore
   `FD_BASE = kernel_target + _Payload_offset`, which would run the FD in place
   and avoid the copy. A WSL build of the current header-enabled shim puts
   `_Payload` at `0xC0`, making the in-place address `0x400000C0` for this
   device's `kernel_addr=0x40000000`; that address is not page-aligned, so do
   not use it as the FD base without changing and revalidating the shim layout.
   A diagnostic `0x200000` FD at `0x40400000` does not overlap the current
   source interval, while `0x40200000` does; neither destination is selected
   until checked against the actual LK mblock allocation and the final FD size.
   Prove the FD fits within its owned memory extent and is linked for that exact
   base. The BootShim copy loop transfers 16-byte chunks, so require
   `FD_SIZE % 16 == 0`; also check `FD_BASE` alignment constraints from the
   chosen SEC/FDF build;
   an unaligned in-place base may not be supported. Reject any non-identical
   overlapping BootShim copy ranges. The recovered LK frees `mb_kernel` before
   handoff, so UEFI must reserve both the live BootShim bytes and FD bytes in
   its own memory map before allocations can reuse them. LK also frees
   `mb_dtb` and `mb_ramdisk`; reserve the incoming FDT and its full
   `linux,initrd-start..end` envelope, even though Block I/O exposes only the
   exact FAT subrange. The reference EDK II
   SEC obtains its initial arena from a named `DXE Heap` descriptor, and its
   MemoryInit PEIM turns the board table into HOBs and halts on overlap. The
   K70U map therefore needs distinct, measured entries for the shim, FD, SEC
   stack/heap, page tables, and DXE heap, with exact resource/allocation
   attributes; it must also describe retained LK/BL31/TEE/framebuffer/DTB
   reservations without overlap. A static table from another SoC is not
   evidence for these addresses. Do not reuse SM8550 or lower-end MediaTek
   addresses by analogy.
5. **Handoff experiment.** First validate the minimal v4 BootShim/UEFI pair
   on the host. On-device, allow at most one bounded direct LK-to-UEFI
   diagnostic attempt; recovered MT6989 LK calls `ufs_deinit()` before chain
   load and Camellia already shows that direct BootShim can fail on another
   MTK target. A reset before UEFI output is a route failure, not proof the
   UEFI build itself is bad. If UEFI starts, first measure whether the full
   payload fits a derived RAM-backed normal `vendor_boot` FAT and qualify the
   LK mblock bounds; this avoids needing UEFI UFS to load the first payload.
   Pursue a UEFI-side UFS restart only if the payload does not fit or an
   external source is required. If direct handoff fails, evaluate
   Linux-preboot only after its exact kernel, initramfs integration and
   readable payload source are established. Do not transplant Camellia's
   addresses, kernel patch or frame map. Stop on LK header, mblock,
   decompression, DTB or AVB errors instead of guessing.
6. **Minimal firmware milestone.** Port/build a MT6989 UEFI FD with serial
   logging, a K70U `MemoryMapLib`, CPU0, physical timer and required boot
   protocols. Mu-Silicium's reference SEC initializes its HOB/arena from a
   memory descriptor named `DXE Heap`; its MemoryInit PEIM converts the board
   table to resource/allocation HOBs and halts on overlaps. The K70U memory
   table must provide the `UEFI FD` region matching
   `PcdFdBaseAddress/PcdFdSize`, keep the live BootShim range, incoming FDT,
   initrd envelope and runtime arenas out of allocatable RAM, and include that
   SEC-required heap entry.
   Use the example map only for its structure, never its chipset addresses.
   Run the platform map overlap validator before device testing. First
   implement a GOP over the framebuffer LK already
   initialized, consuming its runtime FDT handoff; only implement DSI panel
   initialization if that handoff cannot be preserved. If using the Linux
   route, use its verified DRM-linear handoff instead. Validate geometry,
   stride, pixel format, cache maintenance and reserved range before drawing.
   Preserve the exact inputs and logs for the route that passed the handoff
   experiment.
7. **Payload discovery.** First publish the small non-empty FAT ramdisk
   through `UniXNURamDiskDxe`, DiskIoDxe and FAT support; this validates menu
   and config discovery without UFS. The 8 MiB `init_boot` partition is only a
   bootstrap disk, not a presumed full XNU payload store. Measure the complete
   payload and test a separate `vendor_boot_b` candidate whose normal type-1
   ramdisk is a raw FAT and whose recovery type-2 entry is omitted; expose only
   the exact FAT range from the LK-loaded RAM image. Host-validate the v4
   header/table/DTB, LK mblock capacity and 64 MiB partition bound before any
   device test. Keep the stock B images and complete A slot as rollback until
   an explicitly authorized write plan exists. This route avoids UEFI UFS for
   initial payload loading, but not XNU's persistent root requirement. If the
   payload does not fit, use an external source only after qualifying a UEFI
   UFS restart or the exact Linux-preboot route; encrypted userdata is not a
   presumed source. Prefer the recovered local LK MT6989 read path as the
   UEFI host reference and Linux MediaTek source for missing platform
   clock/PHY details. Neither is a ready XNU storage driver.
8. **XNU bootstrap.** Create a Format 2 `UniXNU-rothko` board repository and
   separate `uefi-rothko` platform repository. Create/pin
   `UniXNU-mt6989-common` only for resources genuinely shared across MT6989
   boards; keep Rothko wiring in the device repository. Start with one CPU,
   physical timer, GICv3 and a minimal FDT-to-ADT. Keep GPU, touch, audio,
   Wi-Fi, and power management disabled. Reach the XNU entry and preserve logs
   before adding native UFS/root mount.
9. **Add hardware by dependency.** Prioritize memory/PSCI/GIC, framebuffer
   handoff, UFS and SMMU/DMA, then display/input, GPU, networking, audio and
   power. Each address, interrupt, clock, reset, IOMMU stream and firmware
   dependency must come from the stock MT6989 DTB/DTBO, vendor kernel sources,
   or device logs.

## Fallback Route

Keep direct LK-to-BootShim as a **single diagnostic attempt**, not a
validated route. The current UniXNU Camellia record has device evidence that
direct BootShim reset after about 30 seconds; its Linux-preboot route reached
UEFI/GOP/the UniXNU menu. That alternate is a useful fallback, not the
default: it requires a matching Linux kernel, purpose-built initramfs, jump
entry, verified payload source, GIC/timer cleanup and DRM framebuffer physical
page-run handling. A base-only hot-jump FD also failed there, so do not treat
an FD build or successful compile as handoff evidence.

After a successful direct UEFI entry, first qualify whether the complete
payload fits a RAM-backed normal `vendor_boot` FAT. This avoids a UEFI UFS
restart for initial payload loading. Implement the target-specific LK UFS
restart only if that payload does not fit or an external source is otherwise
needed; XNU's native UFS/root path remains required for persistent storage.
Only consider the Linux-preboot fallback if direct UEFI handoff fails or the
RAM-backed payload route cannot meet the measured payload needs. First
identify the exact kernel behind the matching 3.0.303
`boot.img`; only then decide whether its kernel can host a jump module or needs
a rebuilt kernel. The workspace's device capture and local `vmlinux` report
Linux `6.1.138-android14-11`, but the local `vmlinux`/`Module.symvers` are not
proven to match that boot image, and the workspace has no complete matching
kernel headers/Kbuild tree. They are not yet sufficient to build or load
Camellia's jump implementation.

Keep the active stock v4 `vendor_boot_b` and `dtbo_b` intact for initial direct
handoff tests. The measured device is on slot B; slot A remains the rollback
path and is not a default payload target. If the RAM-backed `vendor_boot`
candidate cannot carry the payload, a Linux-preboot route would need the
matching stock Linux kernel with a purpose-built `init_boot` ramdisk and a
separate, proven pre-Android-readable payload source. Android-encrypted
userdata is not presumed accessible. This fallback requires a
kernel-compatible jump implementation, exact entry/stack and memory
reservations, GIC/timer cleanup, and explicit framebuffer handoff.
Camellia's method of writing a raw UEFI payload to `vendor_boot_a` is not
directly reusable with K70U v4. Do not copy its v2 layout, FD/stack addresses,
or framebuffer map. If a v4 Linux route cannot supply the payload safely, only
then evaluate a separate v2 LK image and partition layout from host-verified
inputs; preserve stock `vendor_boot` until that alternative is independently
shown to work.

The current `K70U-PORT/tools/boot_v4.py` only packages the direct gzip
BootShim/UEFI kernel plus a raw FAT `init_boot`; it is not a Linux-preboot
image builder and cannot package the matching kernel plus custom compressed
initramfs required by that alternate route. Keep those modes separate. Do not
conflate the direct-UEFI v2 header experiment with a Camellia-style Linux
hot-jump image, which needs its own kernel, initramfs, payload source and
entry/stack contract.

The MT6878 malachite record shows that a MediaTek UEFI/XNU route can reach XNU
rootfs, but its hardware and firmware are not interchangeable with MT6989.
The UniXNU `yunluo` MT6789 Format 2 record is only a planned qualification
candidate: it explicitly has no UFS transport in scope and no build/device
qualification. Its listed host (`0x11270000`) also differs from K70U's
`0x112b0000`; it is not an MT6989 driver or a register-map donor.
The local UniXNU records are useful boundary cases: MT6765 dandelion has no
verified UEFI handoff; MT6768/69 merlinx reaches UEFI but storage blocks
progress; MT6833 camellia rejected direct BootShim and succeeded through a
Linux handoff; MT6878 malachite reaches XNU rootfs. See
`UniXNU/docs/zh/devices/dandelion.md`, `merlinx.md`, `camellia.md`, and
`malachite.md`.

## Unresolved Gates

- The live FDT proves the LK mblock free/reserved snapshot, but not the
  pre-release `mb_kernel`, `mb_dtb` and `mb_ramdisk` reservation sizes. The
  recovered boot path explicitly frees those three ranges before FDT export;
  retain the header-derived start candidates and separately qualify their
  exact extents for the custom image.
- The live device confirms slot `_b`, the selected primary panel, and active
  partition capacities. The stock images prove v4 is in use, while recovered
  LK source demonstrates a v2 parser/path; neither proves a real v2 boot. V2
  remains an alternate image-layout gate, not the preferred first image.
- The base DTBO has one ID-0 entry and the live handoff confirms the selected
  panel driver. Remaining panel-specific mode/timing and framebuffer layout
  still need qualification before relying on GOP scanout.
- Determine the firmware FD base, size, entry, stack and safe relocation range
  from a real K70U firmware/memory map.
- The local `uefi-mtk-reference` has no MT6989 platform package, and WSL
  `python3` 3.12.3 lacks `edk2toolext`/`edk2toollib`; no K70U firmware build
  has been proven. MT6789 is a separate SoC and its SEC/clock/memory libraries
  are not a valid substitute. First implement a target-derived Rothko memory
  map and minimal MT6989 SEC/platform integration; then install only the
  required build dependencies and compile the host FD. Do not package the
  current mblock snapshot as-is because LK releases boot ranges before export.
- The checked official Xiaomi kernel branch and its mirror do not include a
  target-named MT6989/Rothko DTS. Use the local stock FDT plus the stock DTBO
  as the binary hardware source of truth: apply the overlay with a compatible
  host tool, preserve the original inputs and provenance, then decompile and
  curate a source DTS for the UniXNU board repository. Do not invent missing
  resource properties or treat the base DTB alone as the final board ADT.
- Verify LK's runtime framebuffer properties and panel index from a captured
  FDT/log. Use the conditional DSI0 `panel2@1` hypothesis only as a lead;
  neither the base FDT nor the recovered comments prove the running panel.
  DSI addresses alone do not provide panel timing, framebuffer format, or
  GOP geometry.
- Treat `platform_pre_chain_load()` as the recovered empty original hook.
  After one bounded direct UEFI test, port the recovered MT6989 LK UFS read
  path into a UEFI provider and qualify the known `ufs_deinit()` teardown,
  clock/PHY retention, SMC, DMA and read-only media access. Use
  Linux-initramfs-to-UEFI only as a fallback if direct handoff fails and exact
  kernel/initramfs/payload inputs are available. Camellia is precedent, not
  proof of K70U compatibility.
- Resolve the exact 3.0.303 kernel source/build inputs before considering a
  Linux jump module. A local capture and `vmlinux` both report
  `6.1.138-android14-11`, but their provenance against this `boot.img` is
  unproven; `Module.symvers` alone is not a replacement for the matching
  generated headers, `.config`, and Kbuild tree.
- Define and host-verify a distinct Linux-preboot packager before selecting
  that route. The existing v4 utility is for the direct BootShim/FAT layout;
  it does not build the required Linux kernel plus initramfs image. Confirm
  active/inactive slot geometry and a safe, readable payload source before
  writing any partition.
- Integrate `K70U-PORT/tools/boot_v4.py` with UniXNU's EDK firmware build and
  supply the platform's verified `FD_BASE`; produce/verify a candidate pair
  from the actual FD and FAT inputs. The generic UniXNU builder remains
  v0-specific, while this separate K70U utility currently supports v4.
  Configure the new
  `UniXNURamDiskDxe` offset/size PCDs in the K70U platform DSC for the type-1
  vendor ramdisk prefix (`0x02719743`) and exact raw-FAT `init_boot` size.
  Never expose the whole FDT initrd range: recovered LK's reported v4 size
  includes the type-2 recovery ramdisk even though normal boot copies only
  type 1, and places bootconfig after that larger range. Host-validate the
  exact FAT subrange against FDT bounds before any device test.
- Retain Android v2 packing/verification as an alternate single-partition
  route and validate its exact LK payload layout before considering a flash.
- Port or qualify MT6989 UEFI services and the required XNU platform drivers.
- The recovered `platform_pre_chain_load()` is an empty original hook.
  Implement and qualify recovery from the known `ufs_deinit()` teardown,
  including HCI writes `0x18/0x34`, clock/PHY state, SMC and DMA. The checked
  Xiaomi Linux source shows `ufshcd_core_init` is the separate UFS
  WLUN SCSI-driver initcall, whereas MediaTek host probing uses
  `module_platform_driver` and `ufshcd_pltfrm_init`; verify against the exact
  3.0.303 kernel and capture its UFS probe log. Do not assume LK's UFS link
  remains live after quiesce.
- Implement MT6989 UFS separately for UEFI and XNU. For UEFI, audit/port the
  recovered target LK HCI/UIC/query/read sequence first, qualify retained
  PHY/clock state after the known teardown, and replace LK
  memory, event, IRQ, cache and secure-call assumptions. Use matched Linux
  MediaTek code for platform-resource gaps; generic `UfsPassThruDxe` is
  optional protocol infrastructure, not the controller driver. XNU still
  needs its own native host, DMA/SMMU and `IOStorageFamily`/root-mount path.
  Do not copy ShengUfs's SM8550 constants or infer compatibility from FDT
  strings alone.
- Select the intended XNU/iOS release and matching UniXNU OS profile, kernel,
  trust-cache and prelink inputs. UEFI/menu success alone is not XNU or
  userland compatibility.
- Identify the actual panel/touch, UFS, PMIC, GPU, Wi-Fi and audio variants and
  the firmware/clock/power/IOMMU state each needs.
- The checked-in UniXNU records show MediaTek ports on MT6765, MT6768/69,
  MT6833, MT6835 and MT6878, but no MT6989 port. Lower-end MTK success is
  evidence for a reusable approach, not proof of MT6989 compatibility.
- A local shallow clone of `uefi-malachite` at
  `K70U-PORT/uefi-mtk-reference` is only a framework reference: its current
  tree contains MediaTek G99/P65/G80 and MT6789 platforms, but no MT6878 or
  MT6989 board package. Do not treat its `stone`/MT6789 memory map or
  `0x40000000` FD base as a K70U value. The reference HEAD is
  `0eb4514db0744b8136a3897ab1af93b713c2c27b`.

## Recovery Policy

The 2026-11-01 [boot container audit](BOOT_CONTAINER_AUDIT.md) records a
confirmed AVB-tail omission in the original direct-boot packer and the
stock-derived entry-reset controls. Consult it before another direct-boot
test; absence of metadata has not yet been isolated on-device as the cause.

Before any user-authorized device test, retain stock images off-device and
confirm recovery to bootloader/fastboot from a failed boot. Do not flash
`lk`, `preloader`, `vbmeta`, `vendor_boot`, or `dtbo` as part of the first
milestone. The preferred first experiment, if later authorized, changes only
the recoverable `boot` and `init_boot` partitions and has tested stock restore
commands ready.
