#!/usr/bin/env python3
"""Build the four offline K70U AVB-preserving experiments in WSL."""

import argparse
import json
import shutil
import struct
import subprocess
from pathlib import Path
from types import SimpleNamespace

from boot_v4 import (
    build_kernel_payload,
    build_v4,
    compress_legacy_lz4,
    decompress_kernel,
    normal_vendor_ramdisk_size,
    verify_v4,
)


def run(command):
    return subprocess.run([str(arg) for arg in command], check=True,
                          capture_output=True, text=True).stdout


def image_header(raw):
    if len(raw) < 64 or raw[56:60] != b"ARM\x64":
        raise ValueError("missing ARM64 Image header")
    offset, size, flags = struct.unpack_from("<QQQ", raw, 8)
    if offset != 0 or size != len(raw) or flags != 0xA:
        raise ValueError("unexpected K70U Image header")
    return {"text_offset": "0x0", "image_size": size, "flags": "0xa"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--boot-template", type=Path, required=True)
    parser.add_argument("--init-boot-template", type=Path, required=True)
    parser.add_argument("--vendor-boot", type=Path, required=True)
    parser.add_argument("--uefi", type=Path, required=True)
    parser.add_argument("--fd", type=Path, required=True)
    parser.add_argument("--fat-image", type=Path, required=True)
    parser.add_argument("--baseline-dir", type=Path, required=True)
    parser.add_argument("--build-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists() and any(args.output.iterdir()):
        raise ValueError("output directory must be fresh; existing results are not overwritten")
    args.output.mkdir(parents=True, exist_ok=True)
    args.build_dir.mkdir(parents=True, exist_ok=True)
    boot_template = args.boot_template.read_bytes()
    init_template = args.init_boot_template.read_bytes()
    vendor = args.vendor_boot.read_bytes()
    if vendor[:8] != b"VNDRBOOT" or struct.unpack_from("<I", vendor, 16)[0] != 0x40000000:
        raise ValueError("this batch requires the K70U vendor_boot kernel target")
    tools = {name: shutil.which(name) for name in ("clang", "llvm-objcopy", "llvm-objdump")}
    if not all(tools.values()):
        raise ValueError("use the existing WSL LLVM build environment")
    manifest = {
        "status": "OFFLINE_BUILT_NOT_DEVICE_TESTED",
        "avb_policy": "Stock metadata/footer retained at original offsets; payload hashes are stale; not re-signed",
        "build_directory": str(args.build_dir),
        "inputs": {name: str(getattr(args, name)) for name in
                   ("boot_template", "init_boot_template", "vendor_boot", "uefi", "fd", "fat_image")},
        "artifacts": {},
    }

    def emit(filename, kernel, ramdisk, template, **details):
        image = build_v4(template, kernel, ramdisk, filename, preserve_avb_tail=True)
        report = verify_v4(image, kernel, ramdisk, filename, template=template,
                           preserve_avb_tail=True)
        if kernel:
            raw, _ = decompress_kernel(kernel)
            report["arm64_image"] = image_header(raw)
        report.update(details)
        report["device_tested"] = False
        (args.output / filename).write_bytes(image)
        manifest["artifacts"][filename] = report
        print(f"BUILT {filename}: kernel={len(kernel)} ramdisk={len(ramdisk)} AVB=preserved", flush=True)

    source = Path(__file__).resolve().parents[1] / "uefi-mtk-reference/BootShim/BootShimEntryProbe.S"
    cases = [
        ("reset-0s", 0, 1, 0, "entry-probe-direct-smc.bin", "boot-entry-probe-lz4-direct-smc.img"),
        ("reset-20s", 20, 0, 0, "entry-probe-20s.bin", "boot-entry-probe-lz4-20s.img"),
        ("pstore-20s", 20, 0, 1, None, None),
    ]
    for name, delay, direct, pstore, old_raw, old_boot in cases:
        obj = args.build_dir / f"{name}.o"
        binary = args.build_dir / f"{name}.bin"
        run([tools["clang"], "--target=aarch64-none-elf", "-c", source,
             f"-DPROBE_DELAY_S={delay}", f"-DPROBE_DIRECT_RESET={direct}",
             f"-DPROBE_PSTORE={pstore}", "-o", obj])
        run([tools["llvm-objcopy"], "-O", "binary", obj, binary])
        raw = binary.read_bytes()
        image_header(raw)
        if old_raw:
            if raw != (args.baseline_dir / old_raw).read_bytes():
                raise ValueError(f"{name}: raw probe differs from the previous control")
            baseline = (args.baseline_dir / old_boot).read_bytes()
            size = struct.unpack_from("<I", baseline, 8)[0]
            kernel = baseline[4096:4096 + size]
            if decompress_kernel(kernel)[0] != raw:
                raise ValueError(f"{name}: baseline compressed payload differs")
        else:
            kernel = compress_legacy_lz4(raw)
        assembly = run([tools["llvm-objdump"], "-d", "--no-show-raw-insn",
                        "--start-address=0x40", "--stop-address=0x150", obj])
        (args.output / f"{name}-assembly.txt").write_text(assembly)
        emit(f"boot-avb-{name}.img", kernel, b"", boot_template,
             delay_seconds=delay, direct_smc=bool(direct), pstore=bool(pstore),
             compressed_payload_matches_previous_control=bool(old_boot))
        if pstore:
            manifest["artifacts"][f"boot-avb-{name}.img"].update({
                "pmsg_base": "0x480f0000", "pmsg_zone_bytes": 0x80000,
                "pmsg_marker": "K70U_AVB_PMSG_ENTRY_V1", "replaces_previous_pmsg_history": True,
            })

    fd_args = SimpleNamespace(kernel_gzip=None, kernel_lz4=None, uefi=str(args.uefi),
                              fd=str(args.fd), fd_base=0x40400000, fd_size=0x200000,
                              kernel_compression="lz4")
    kernel, firmware_report = build_kernel_payload(fd_args, 0x40000000)
    emit("boot-avb-uefi.img", kernel, b"", boot_template,
         firmware_rebuilt=False, bootshim_recompiled=True, **firmware_report)
    fat = args.fat_image.read_bytes()
    if len(fat) != 0x100000 or fat[510:512] != b"\x55\xaa":
        raise ValueError("UEFI ramdisk must be the configured 1 MiB FAT image")
    emit("init_boot-avb-uefi.img", b"", fat, init_template,
         vendor_ramdisk_prefix_bytes=normal_vendor_ramdisk_size(vendor))
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (args.output / "README.md").write_text(r"""# K70U AVB Experiment Batch

Status: offline-built, not tested on the phone. These are diagnostic images.
Stock AVB metadata/footer are retained, but old payload hashes are stale.
Nothing has been re-signed. All four boot payloads use legacy LZ4.

| Test | boot_b | init_boot_b |
| --- | --- | --- |
| Immediate PSCI reset, no timer-register accesses | boot-avb-reset-0s.img | Keep working KSU image |
| Wait 20 seconds, then PSCI reset | boot-avb-reset-20s.img | Keep working KSU image |
| Write pmsg marker, wait 20 seconds, then reset | boot-avb-pstore-20s.img | Keep working KSU image |
| Full UEFI | boot-avb-uefi.img | init_boot-avb-uefi.img |

The 0s/20s probes retain their previous raw AND compressed payloads exactly;
only the stock AVB envelope is added. They are not the stock-kernel carrier.
The known working stock-carrier controls remain in ../boot-entry-audit/.

The pstore test replaces only the RAM pmsg ring at 0x480F0000 with
K70U_AVB_PMSG_ENTRY_V1. It does not use UEFI or framebuffer. RAM retention
through reset/DA recovery has not been established by an offline build.
After restoring Android, inspect /sys/fs/pstore/pmsg-ramoops-0 promptly.

The UEFI FD is the existing compiled 2 MiB firmware; its BootShim is
recompiled. The wrapper sets Image text_offset=0 and flags=0xA.

## Later Device Tests

Run in PowerShell from the tools directory:

```powershell
Set-Location F:\k70u\tools
$da = @('--da', '.\DA_BR_1.0_2.0.bin', '--backend', 'libusb', '--vid', '3725', '--pid', '8192')
.\antumbra.exe write boot_b .\avb-v1\boot-avb-reset-0s.img @da
```

While Antumbra is waiting, run `adb reboot` in a second terminal.
Change the image name according to the table for the other tests.
Wait for the write-completed message. Only for full UEFI, write its FAT
init_boot in the same DA session before rebooting:

```powershell
.\antumbra.exe write init_boot_b .\avb-v1\init_boot-avb-uefi.img @da
```

Explicitly boot after all writes are complete:

```powershell
.\antumbra.exe reboot @da
```

Do not wait for ADB from these probes or UEFI. They do not run Android.
Do not intercept the first normal preloader window during timing tests.

## Restore Android

Start the following write waiting for the NEXT preloader window after the
test has executed. The reset probes generate that window themselves.
If UEFI does not reset, a manual power-key restart is needed, not ADB.

```powershell
.\antumbra.exe write boot_b C:\Users\24718\Desktop\output\boot.img @da
```

Only if the UEFI init_boot was flashed, also restore KSU before reboot:

```powershell
.\antumbra.exe write init_boot_b F:\k70u\os\3.0.303\init_boot_b_20261031.img @da
```

After the write-completed messages:

```powershell
.\antumbra.exe reboot @da
```

Once Android is back, inspect pstore promptly with correct root quoting:

```powershell
adb shell 'su -c "ls -l /sys/fs/pstore"'
adb shell 'su -c "cat /sys/fs/pstore/pmsg-ramoops-0"' | Select-String 'K70U_AVB_PMSG_ENTRY_V1'
```

Do not write lk, preloader, vbmeta, vendor_boot or dtbo for these tests.

manifest.json records inputs, packing checks and the untested-device status.
""")
    print(f"BATCH_COMPLETE {args.output}", flush=True)


if __name__ == "__main__":
    main()
