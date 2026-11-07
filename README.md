# UniXNU UEFI for Redmi K70 Ultra

UEFI firmware platform for running UniXNU on the Xiaomi Redmi K70 Ultra
(`rothko`, MediaTek Dimensity 9300 / MT6989).

This repository contains the device platform, firmware drivers, memory map,
display handoff, UniXNU ramdisk integration and boot-chain glue required by
the matching [`UniXNU-rothko`](https://github.com/woaphone/UniXNU-rothko)
device repository.

The current tree is the local `basecore/rothko` delivery imported on
2026-11-06. It includes the unx18 UFS safety pass. Build-time ELF and firmware
outputs, device dumps, private keys and boot images are not tracked.

## Device target

| Item | Value |
| --- | --- |
| Device | Xiaomi Redmi K70 Ultra |
| Codename | `rothko` |
| SoC | MediaTek MT6989 / Dimensity 9300 |
| Architecture | AArch64 |
| Firmware layout | v4 boot image, 2 MiB FD at `0x40400000` |
| Display | 1220x2712, 32 bpp, command-mode DSI |
| Storage | UFS4, LU2 userdata, 4096-byte logical blocks |
| UniXNU donor | iPadOS 17.7.11 / 21H461 |

## Included integration

- MT6989 SEC entry, GICv3, timer, GPIO, PMIC key resources and memory-map glue.
- `RothkoDisplayDxe` with the board panel bounds and firmware framebuffer setup.
- Explicit CMD-mode frame presentation and visible Darwin handoff markers.
- `RothkoHighMemDxe` for the MT6989 high-memory ranges.
- `RothkoWatchdogDxe` for the board watchdog path.
- `UniXNURamDiskDxe` integration with the K70U initrd FAT slice.
- `DarwinBoot` handoff that preserves `boot_args`, kernel entry and the firmware
  GIC state needed by the matching XNU payload.
- Correct three-key routing: volume up on GPIO196, volume down on MT6363
  `HOMEKEY`, and power on MT6363 `PWRKEY`.

## UFS safety state

The unx18 pass removes the known refclk attribute rewrite and limits several
firmware storage write paths:

- `Platform.RefClkFreq` is left obsolete so generic UFS PassThru does not rewrite
  the device `bRefClkFreq` property.
- MTK device-reset and refclk SMC paths are disabled.
- `MTKUFS_SKIP_PHY_POWERON` returns before the TOPCKGEN, UFSAO and PDN writes.
- The UFS Device Config protocol is not published.
- FORMAT UNIT, WRITE(6/10/12/16), WRITE BUFFER, UNMAP and SECURITY PROTOCOL OUT
  are rejected by the retained pass-through filter.
- Published disk Block I/O is marked read-only.

The 2026-11-07 offline recheck found that this is a partial opcode denylist:
other CDBs are forwarded, so the current code does not establish a complete
media/device-state write prohibition. PreHce also still toggles RTFF through
SMC BIT9 and changes HCI, AHIT, host options and link state. Skipping PHY
power-on does not suppress those separate paths. Internal `fDeviceInit`
initialization is retained.

Stock Linux supports a 52 MHz refclk attribute, but neither the previous
capture nor the effective DT establishes the device's stored value during the
unx17 attempt. The 26 MHz branch is confirmed in source; execution, successful
persistence and causation of BROM are not established.

This is a source and offline-build record. The UFS command/DMA path and hardware
behavior after the earlier BROM incident are not verified. The exact cause of
that incident remains unresolved; unx18 is not a recovered-device baseline.

## Repository layout

```text
Platforms/Xiaomi/rothkoPkg/   K70U platform DSC/FDF, board drivers and build entry
Silicon/MediaTek/            inherited MediaTek package namespaces
Silicon/Silicium/             shared Silicium firmware components
Resources/Configs/rothko.toml boot, FD and handoff configuration
BootShim/                     boot-loader shim source
Mu_Basecore/                  pinned Project Mu basecore submodule
Common/Mu/                    pinned Project Mu submodule
Common/Mu_OEM_Sample/         pinned OEM sample submodule
Binaries/                     pinned firmware binary submodule
Silicium-ACPI/                pinned ACPI submodule
```

Board-specific code belongs under `Platforms/Xiaomi/rothkoPkg`. Shared fixes
that also apply to other targets should be kept narrow and documented before
they are proposed upstream.

## Prerequisites

- Linux, preferably Ubuntu 24.04. WSL2 is supported.
- Git with recursive submodule support.
- Python 3.11 or newer.
- `stuart`, `edk2-pytool-library`, `edk2-pytool-extensions`, `nasm`, `iasl`,
  `dtc`, Clang/LLVM and the packages installed by `setup_env.sh`.
- A sibling checkout of the matching UniXNU device repository.

Initialize the firmware source and submodules:

```sh
git clone --recursive git@github.com:ChallengeThePeak/Silicium-Rothko.git uefi-rothko
cd uefi-rothko
git submodule update --init --recursive
```

The current `DeviceBuild.py` expects the device package at
`<parent>/UniXNU/package`. A convenient layout is:

```text
rothko-build/
  UniXNU/package -> ../UniXNU-rothko/package
  uefi-rothko/
```

Create the link after cloning both repositories:

```sh
mkdir -p rothko-build
cd rothko-build
git clone --recursive git@github.com:ChallengeThePeak/Silicium-Rothko.git uefi-rothko
git clone git@github.com:woaphone/UniXNU-rothko.git
ln -s ../UniXNU-rothko UniXNU
cd uefi-rothko
```

Run the dependency setup once:

```sh
./setup_env.sh -p apt
python3 -m pip install -r pip-requirements.txt
python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --update
python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --setup
```

## Build the FD

The established Linux build command is:

```sh
python3 Platforms/Xiaomi/rothkoPkg/DeviceBuild.py \
  TARGET=DEBUG \
  ENABLE_SECUREBOOT=0 \
  FD_BASE=0x40400000 \
  FD_SIZE=0x200000 \
  FD_BLOCKS=0x200 \
  DEVICE_MODEL=0 \
  DISABLE_DEBUG_MACRO_CHECK=TRUE
```

The generated firmware volume is:

```text
Build/rothkoPkg/DEBUG_CLANGDWARF/FV/SILICIUM_UEFI.fd
```

This repository produces the firmware FD. The boot, init_boot and vendor_boot
images are assembled by the `UniXNU-rothko` packaging flow with its pinned
payload, kernel and boot-image templates.

## Offline build record

The unx18 firmware build completed with 59 built-in image validations.

| Artifact | SHA-256 |
| --- | --- |
| `SILICIUM_UEFI.fd` | `7fedccdf2097080689526b0fcea14caa22c70d9dcf14af035dd841128c921bf9` |
| `boot` | `9fb1c96789cae025b6c1c6f91492c107cfda9205a4676ab5cabf35b97cad8743` |
| `init_boot` | `c0cadc62b8cdb992c7c92c4a43b86902c657d74e8ad1d4e05801b0337b9834d7` |
| `vendor_boot` | `37500c9805e91b70d597a9ee8b73eb02846eb1e085a7cc74f58bf09275c64667` |

The image hashes identify the offline delivery; generated images are kept
outside Git.

## Verification status

| Area | Status |
| --- | --- |
| UEFI DeviceBuild and `stuart` | Builds successfully offline |
| Darwin handoff and XNU entry | Observed on earlier matching candidates |
| GOP/CMD presentation | Observed on earlier matching candidates |
| Three physical keys | Implemented; full UEFI interaction still needs a matched run |
| UFS enumeration | Link/DP seen, but the UFS command/DMA path is not closed |
| UFS write protection | BlockIo read-only and partial CDB denylist; complete command boundary remains open |
| Post-BROM recovery | Not performed by this repository |

## Troubleshooting

`missing file: ../UniXNU/package` means the sibling device-package link is
missing. Recreate the `UniXNU/package -> ../UniXNU-rothko/package` link from
the layout above.

`Required submodule is missing` means the recursive submodule update was not
completed. Run `git submodule update --init --recursive`.

If the build reuses stale artifacts, verify the active output path and use a
fresh output directory rather than deleting an existing build tree. This
project keeps prior outputs for attribution.

## References

- [Matching UniXNU device repository](https://github.com/woaphone/UniXNU-rothko)
- [UniXNU porting documentation](https://unixnu.com/porting/)
- [UniXNU UEFI integration](https://unixnu.com/porting/uefi-firmware)
- [UniXNU bring-up sequence](https://unixnu.com/porting/bring-up)

## License

The platform and shared source retain the licenses of their upstream
components. See `LICENSE` and the license files under each submodule.
