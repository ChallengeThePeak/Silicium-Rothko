#!/usr/bin/env python3
"""Build and verify K70U v4 boot/init_boot images from stock templates."""

import argparse
import ctypes
import ctypes.util
import gzip
import json
import struct
import sys
import tempfile
import zlib
from functools import lru_cache
from pathlib import Path

PAGE_SIZE = 4096
BOOT_HEADER_SIZE = 1584
VENDOR_HEADER_SIZE = 2128
VENDOR_TABLE_ENTRY_SIZE = 108
BOOT_MAGIC = b"ANDROID!"
VENDOR_MAGIC = b"VNDRBOOT"
LZ4_MAGIC = b"\x02\x21\x4c\x18"
LZ4_BLOCK_SIZE = 8 * 1024 * 1024
WORKSPACE = Path(__file__).resolve().parents[2]
UNIXNU_SCRIPTS = WORKSPACE / "UniXNU" / "scripts"
if UNIXNU_SCRIPTS.is_dir():
    sys.path.insert(0, str(UNIXNU_SCRIPTS))


def align(value, boundary=PAGE_SIZE):
    return (value + boundary - 1) // boundary * boundary


def u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


@lru_cache(maxsize=1)
def lz4_library():
    name = ctypes.util.find_library("lz4")
    if not name:
        raise ValueError("legacy LZ4 requires liblz4; use the existing WSL build runtime")
    library = ctypes.CDLL(name)
    library.LZ4_compressBound.argtypes = [ctypes.c_int]
    library.LZ4_compressBound.restype = ctypes.c_int
    library.LZ4_compress_HC.argtypes = [ctypes.c_void_p, ctypes.c_void_p,
                                       ctypes.c_int, ctypes.c_int, ctypes.c_int]
    library.LZ4_compress_HC.restype = ctypes.c_int
    library.LZ4_decompress_safe.argtypes = [ctypes.c_void_p, ctypes.c_void_p,
                                           ctypes.c_int, ctypes.c_int]
    library.LZ4_decompress_safe.restype = ctypes.c_int
    return library


def compress_legacy_lz4(raw):
    if not raw:
        raise ValueError("cannot compress an empty kernel")
    library = lz4_library()
    result = bytearray(LZ4_MAGIC)
    for offset in range(0, len(raw), LZ4_BLOCK_SIZE):
        block = raw[offset:offset + LZ4_BLOCK_SIZE]
        output = ctypes.create_string_buffer(library.LZ4_compressBound(len(block)))
        size = library.LZ4_compress_HC(block, output, len(block), len(output), 12)
        if size <= 0:
            raise ValueError("LZ4 compression failed")
        result.extend(struct.pack("<I", size))
        result.extend(output.raw[:size])
    return bytes(result)


def decompress_kernel(kernel):
    if kernel.startswith(b"\x1f\x8b"):
        try:
            return gzip.decompress(kernel), "gzip"
        except (OSError, EOFError, zlib.error) as error:
            raise ValueError("kernel is not a complete gzip stream") from error
    if not kernel.startswith(LZ4_MAGIC):
        raise ValueError("kernel must use gzip or legacy LZ4")
    library = lz4_library()
    pos = len(LZ4_MAGIC)
    blocks = []
    while pos < len(kernel):
        if pos + 4 > len(kernel):
            raise ValueError("truncated LZ4 block header")
        size = u32(kernel, pos)
        pos += 4
        if size == int.from_bytes(LZ4_MAGIC, "little"):
            continue
        if not size or pos + size > len(kernel):
            raise ValueError("invalid LZ4 block size")
        output = ctypes.create_string_buffer(LZ4_BLOCK_SIZE)
        count = library.LZ4_decompress_safe(kernel[pos:pos + size], output, size, len(output))
        if count <= 0:
            raise ValueError("LZ4 decompression failed")
        blocks.append(output.raw[:count])
        pos += size
    if not blocks:
        raise ValueError("empty LZ4 stream")
    return b"".join(blocks), "legacy-lz4"


def check_boot_template(data, label):
    if len(data) < PAGE_SIZE or data[:8] != BOOT_MAGIC:
        raise ValueError(f"{label}: invalid Android boot image")
    if u32(data, 40) != 4 or u32(data, 20) != BOOT_HEADER_SIZE:
        raise ValueError(f"{label}: expected Android boot header v4")
    if u32(data, 1580) != 0:
        raise ValueError(f"{label}: nonzero boot signature area is unsupported")


def avb_tail_offset(template, label):
    if len(template) < 64:
        raise ValueError(f"{label}: missing AVB footer")
    magic, major, minor, original_size, vbmeta_offset, vbmeta_size = struct.unpack(
        "!4sIIQQQ28x", template[-64:])
    start = PAGE_SIZE + align(u32(template, 8)) + align(u32(template, 12))
    if (magic != b"AVBf" or major != 1 or start > original_size or
            original_size > vbmeta_offset or vbmeta_size < 256 or
            vbmeta_offset + vbmeta_size > len(template) - 64 or
            template[vbmeta_offset:vbmeta_offset + 4] != b"AVB0"):
        raise ValueError(f"{label}: invalid stock AVB envelope")
    return start


def normal_vendor_ramdisk_size(data):
    if len(data) < PAGE_SIZE or data[:8] != VENDOR_MAGIC:
        raise ValueError("vendor_boot: invalid image")
    if u32(data, 8) != 4 or u32(data, 12) != PAGE_SIZE:
        raise ValueError("vendor_boot: expected v4 with 4096-byte pages")
    if u32(data, 2096) != VENDOR_HEADER_SIZE:
        raise ValueError("vendor_boot: unexpected v4 header size")

    ramdisk_size = u32(data, 24)
    dtb_size = u32(data, 2100)
    table_size = u32(data, 2112)
    entry_count = u32(data, 2116)
    entry_size = u32(data, 2120)
    if entry_size != VENDOR_TABLE_ENTRY_SIZE or table_size != entry_count * entry_size:
        raise ValueError("vendor_boot: invalid ramdisk table dimensions")

    table_offset = PAGE_SIZE + align(ramdisk_size) + align(dtb_size)
    if table_offset + table_size > len(data):
        raise ValueError("vendor_boot: ramdisk table exceeds image")

    normal = []
    for index in range(entry_count):
        entry = table_offset + index * entry_size
        size, offset, ramdisk_type = struct.unpack_from("<III", data, entry)
        if offset + size > ramdisk_size:
            raise ValueError(f"vendor_boot: ramdisk table entry {index} is out of bounds")
        if ramdisk_type == 1:
            normal.append(size)
    if len(normal) != 1 or normal[0] == 0:
        raise ValueError("vendor_boot: expected exactly one non-empty normal-boot ramdisk")
    return normal[0]


def validate_bootshim_ranges(kernel_target, shim_size, fd_size, fd_base):
    source_start = kernel_target + shim_size
    source_end = source_start + fd_size
    target_start = fd_base
    target_end = target_start + fd_size
    if target_start == source_start:
        return True
    live_start = kernel_target
    live_end = source_end
    if (target_start < live_end) and (live_start < target_end):
        raise ValueError("BootShim FD copy target partially overlaps its live source image")
    return False


def build_v4(template, kernel, ramdisk, label, *, preserve_avb_tail=False):
    check_boot_template(template, label)
    if len(kernel) > 0xFFFFFFFF or len(ramdisk) > 0xFFFFFFFF:
        raise ValueError(f"{label}: payload exceeds v4 header limits")
    if len(kernel) and len(ramdisk):
        raise ValueError(f"{label}: this target uses kernel-only boot or ramdisk-only init_boot")
    if ramdisk and len(ramdisk) % 512:
        raise ValueError(f"{label}: ramdisk disk size must be a multiple of 512")

    header = bytearray(template[:PAGE_SIZE])
    struct.pack_into("<I", header, 8, len(kernel))
    struct.pack_into("<I", header, 12, len(ramdisk))

    image = bytearray(header)
    image.extend(kernel)
    image.extend(b"\0" * (align(len(image)) - len(image)))
    image.extend(ramdisk)
    image.extend(b"\0" * (align(len(image)) - len(image)))
    if len(image) > len(template):
        raise ValueError(f"{label}: image payload exceeds template partition size")
    if preserve_avb_tail:
        tail = avb_tail_offset(template, label)
        if len(image) > tail:
            raise ValueError(f"{label}: payload would overlap the preserved AVB tail")
        image.extend(b"\0" * (tail - len(image)))
        image.extend(template[tail:])
    else:
        image.extend(b"\0" * (len(template) - len(image)))
    return bytes(image)


def verify_v4(image, kernel, ramdisk, label, *, template=None, preserve_avb_tail=False):
    check_boot_template(image, label)
    kernel_size = u32(image, 8)
    ramdisk_size = u32(image, 12)
    if kernel_size != len(kernel) or ramdisk_size != len(ramdisk):
        raise ValueError(f"{label}: payload sizes do not match")
    kernel_start = PAGE_SIZE
    ramdisk_start = PAGE_SIZE + align(kernel_size)
    if image[kernel_start:kernel_start + kernel_size] != kernel:
        raise ValueError(f"{label}: kernel payload does not match")
    if image[ramdisk_start:ramdisk_start + ramdisk_size] != ramdisk:
        raise ValueError(f"{label}: ramdisk payload does not match")
    if preserve_avb_tail:
        if template is None:
            raise ValueError(f"{label}: AVB preservation verification requires the template")
        tail = avb_tail_offset(template, label)
        if (len(image) != len(template) or ramdisk_start + ramdisk_size > tail or
                image[tail:] != template[tail:] or
                any(image[ramdisk_start + ramdisk_size:tail])):
            raise ValueError(f"{label}: preserved AVB envelope or padding differs")
    elif any(image[ramdisk_start + ramdisk_size:]):
        raise ValueError(f"{label}: nonzero data follows payload")
    compression = None
    decoded_size = 0
    if kernel:
        decoded, compression = decompress_kernel(kernel)
        decoded_size = len(decoded)
    return {
        "partition_bytes": len(image),
        "header_version": 4,
        "header_size": BOOT_HEADER_SIZE,
        "signature_size": u32(image, 1580),
        "kernel_bytes": kernel_size,
        "ramdisk_bytes": ramdisk_size,
        "kernel_offset": kernel_start,
        "ramdisk_offset": ramdisk_start,
        "compression": compression,
        "decoded_kernel_bytes": decoded_size,
        "avb_tail_preserved": preserve_avb_tail,
        "avb_payload_resigned": False,
    }


def build_kernel_payload(args, kernel_target):
    prebuilt = args.kernel_gzip or getattr(args, "kernel_lz4", None)
    if prebuilt:
        if args.uefi or args.fd_base is not None or args.fd_size is not None:
            raise ValueError("--kernel-gzip cannot be combined with BootShim/FD options")
        return Path(prebuilt).read_bytes(), {}

    if not args.uefi or not args.fd or args.fd_base is None:
        raise ValueError("provide --kernel-gzip, or provide --uefi, --fd, and --fd-base")
    firmware = Path(args.fd).read_bytes()
    if args.fd_size is not None and len(firmware) != args.fd_size:
        raise ValueError(f"FD is {len(firmware):#x} bytes, expected {args.fd_size:#x}")
    if len(firmware) % 16:
        raise ValueError("BootShim copies the FD in 16-byte chunks; FD size must be a multiple of 16")

    try:
        from unixnu.bootimg import compile_shim
    except ImportError as error:
        raise ValueError(f"cannot import UniXNU BootShim builder from {UNIXNU_SCRIPTS}") from error

    with tempfile.TemporaryDirectory(prefix="k70u-boot-v4-") as temp:
        shim = compile_shim(
            Path(args.uefi).resolve(),
            args.fd_base,
            len(firmware),
            True,
            Path(temp),
        )
    in_place = validate_bootshim_ranges(kernel_target, len(shim), len(firmware), args.fd_base)
    # FD_BASE is a relocation destination, not the Linux Image load offset.
    shim = bytearray(shim)
    if shim[56:60] != b"ARM\x64":
        raise ValueError("BootShim is missing its ARM64 Image header")
    struct.pack_into("<Q", shim, 8, kernel_target % 0x200000)
    struct.pack_into("<Q", shim, 24, 0xA)
    payload = bytes(shim) + firmware
    kernel = (compress_legacy_lz4(payload)
              if getattr(args, "kernel_compression", "gzip") == "lz4"
              else gzip.compress(payload, mtime=0))
    return kernel, {
        "shim_bytes": len(shim),
        "fd_bytes": len(firmware),
        "fd_base": hex(args.fd_base),
        "fd_load_in_place": in_place,
        "bootshim_payload_bytes": len(payload),
        "image_text_offset": hex(kernel_target % 0x200000),
        "image_flags": "0xa",
    }


def pack(args):
    inputs = {
        Path(args.boot_template).resolve(),
        Path(args.init_boot_template).resolve(),
        Path(args.vendor_boot).resolve(),
        Path(args.fat_image).resolve(),
    }
    if args.kernel_gzip:
        inputs.add(Path(args.kernel_gzip).resolve())
    if getattr(args, "kernel_lz4", None):
        inputs.add(Path(args.kernel_lz4).resolve())
    if args.fd:
        inputs.add(Path(args.fd).resolve())
    outputs = [Path(args.boot_output).resolve(), Path(args.init_boot_output).resolve()]
    if args.report:
        outputs.append(Path(args.report).resolve())
    if len(set(outputs)) != len(outputs) or inputs.intersection(outputs):
        raise ValueError("output paths must be distinct from each other and all inputs")
    if not args.force and any(path.exists() for path in outputs):
        raise ValueError("an output already exists; choose another path or pass --force")

    boot_template = Path(args.boot_template).read_bytes()
    init_template = Path(args.init_boot_template).read_bytes()
    vendor_boot = Path(args.vendor_boot).read_bytes()
    kernel_target = u32(vendor_boot, 16)
    if kernel_target == 0:
        raise ValueError("vendor_boot: kernel load address is zero")
    kernel, kernel_report = build_kernel_payload(args, kernel_target)
    fat = Path(args.fat_image).read_bytes()

    if len(fat) < 512 or fat[510:512] != b"\x55\xaa":
        raise ValueError("fat-image: missing a valid 0x55AA boot-sector signature")
    vendor_prefix = normal_vendor_ramdisk_size(vendor_boot)
    preserve = getattr(args, "preserve_avb_tail", False)
    boot = build_v4(boot_template, kernel, b"", "boot", preserve_avb_tail=preserve)
    init_boot = build_v4(init_template, b"", fat, "init_boot", preserve_avb_tail=preserve)

    boot_report = verify_v4(boot, kernel, b"", "boot", template=boot_template,
                            preserve_avb_tail=preserve)
    init_report = verify_v4(init_boot, b"", fat, "init_boot", template=init_template,
                            preserve_avb_tail=preserve)
    init_report["vendor_ramdisk_prefix_bytes"] = vendor_prefix
    init_report["fat_disk_offset_in_initrd"] = vendor_prefix
    report = {"boot": boot_report, "init_boot": init_report}
    report["boot"].update(kernel_report)
    report["boot"]["kernel_target"] = hex(kernel_target)

    Path(args.boot_output).write_bytes(boot)
    Path(args.init_boot_output).write_bytes(init_boot)
    if args.report:
        Path(args.report).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--boot-template", required=True)
    parser.add_argument("--init-boot-template", required=True)
    parser.add_argument("--vendor-boot", required=True)
    kernel_input = parser.add_mutually_exclusive_group()
    kernel_input.add_argument("--kernel-gzip", help="prebuilt gzip BootShim/UEFI kernel payload")
    kernel_input.add_argument("--kernel-lz4", help="prebuilt legacy-LZ4 kernel payload")
    kernel_input.add_argument("--fd", help="built UEFI firmware volume; compiles BootShim automatically")
    parser.add_argument("--uefi", help="Mu-Silicium checkout containing BootShim/BootShim.S")
    parser.add_argument("--fd-base", type=lambda value: int(value, 0),
                        help="physical address used to build the UEFI firmware volume")
    parser.add_argument("--fd-size", type=lambda value: int(value, 0),
                        help="optional expected firmware volume size")
    parser.add_argument("--kernel-compression", choices=("gzip", "lz4"), default="gzip",
                        help="compression for a newly built BootShim/FD payload")
    parser.add_argument("--preserve-avb-tail", action="store_true",
                        help="retain stock AVB bytes at their original offsets; does not re-sign payloads")
    parser.add_argument("--fat-image", required=True)
    parser.add_argument("--boot-output", required=True)
    parser.add_argument("--init-boot-output", required=True)
    parser.add_argument("--report")
    parser.add_argument("--force", action="store_true", help="replace existing output files")
    args = parser.parse_args()
    pack(args)


if __name__ == "__main__":
    main()
