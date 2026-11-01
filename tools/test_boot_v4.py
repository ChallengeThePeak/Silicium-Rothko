import gzip
import struct
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from boot_v4 import (
    PAGE_SIZE,
    build_kernel_payload,
    build_v4,
    compress_legacy_lz4,
    decompress_kernel,
    normal_vendor_ramdisk_size,
    validate_bootshim_ranges,
    verify_v4,
)


def boot_template(size):
    image = bytearray(size)
    image[:8] = b"ANDROID!"
    struct.pack_into("<I", image, 20, 1584)
    struct.pack_into("<I", image, 40, 4)
    return bytes(image)


def vendor_boot_fixture():
    page = PAGE_SIZE
    ramdisk_size = 1024
    dtb_size = 512
    table_offset = page + page + page
    image = bytearray(table_offset + 2 * 108)
    image[:8] = b"VNDRBOOT"
    struct.pack_into("<I", image, 8, 4)
    struct.pack_into("<I", image, 12, page)
    struct.pack_into("<I", image, 16, 0x40000000)
    struct.pack_into("<I", image, 24, ramdisk_size)
    struct.pack_into("<I", image, 2096, 2128)
    struct.pack_into("<I", image, 2100, dtb_size)
    struct.pack_into("<I", image, 2112, 216)
    struct.pack_into("<I", image, 2116, 2)
    struct.pack_into("<I", image, 2120, 108)
    struct.pack_into("<III", image, table_offset, 512, 0, 1)
    struct.pack_into("<III", image, table_offset + 108, 512, 512, 2)
    return bytes(image)


def avb_boot_fixture():
    image = bytearray(boot_template(32768))
    struct.pack_into("<I", image, 8, 4096)
    image[8192:8200] = b"GKI-TAIL"
    image[12288:12292] = b"AVB0"
    image[-64:] = struct.pack("!4sIIQQQ28x", b"AVBf", 1, 0, 12288, 12288, 256)
    return bytes(image)


class BootV4Tests(unittest.TestCase):
    def test_preserved_avb_tail_is_exact_and_overlap_is_rejected(self):
        template = avb_boot_fixture()
        kernel = gzip.compress(b"new payload")
        image = build_v4(template, kernel, b"", "boot", preserve_avb_tail=True)
        self.assertEqual(image[8192:], template[8192:])
        report = verify_v4(image, kernel, b"", "boot", template=template,
                           preserve_avb_tail=True)
        self.assertTrue(report["avb_tail_preserved"])
        self.assertFalse(report["avb_payload_resigned"])
        with self.assertRaisesRegex(ValueError, "overlap"):
            build_v4(template, b"x" * 4097, b"", "boot", preserve_avb_tail=True)
        broken = bytearray(image)
        broken[8192] ^= 1
        with self.assertRaisesRegex(ValueError, "envelope"):
            verify_v4(bytes(broken), kernel, b"", "boot", template=template,
                       preserve_avb_tail=True)

    def test_legacy_lz4_round_trip_and_truncated_frame(self):
        raw = b"probe" * 1024
        packed = compress_legacy_lz4(raw)
        self.assertEqual(decompress_kernel(packed), (raw, "legacy-lz4"))
        with self.assertRaisesRegex(ValueError, "block size"):
            decompress_kernel(packed[:-1])

    def test_normal_ramdisk_comes_from_type_one_entry(self):
        self.assertEqual(normal_vendor_ramdisk_size(vendor_boot_fixture()), 512)

    def test_v4_boot_pair_round_trip(self):
        kernel = gzip.compress(b"synthetic BootShim and firmware")
        fat = bytearray(1024)
        fat[510:512] = b"\x55\xaa"
        boot = build_v4(boot_template(8192), kernel, b"", "boot")
        init_boot = build_v4(boot_template(8192), b"", bytes(fat), "init_boot")
        self.assertEqual(verify_v4(boot, kernel, b"", "boot")["signature_size"], 0)
        self.assertEqual(verify_v4(init_boot, b"", bytes(fat), "init_boot")["ramdisk_offset"], PAGE_SIZE)

    def test_accepts_a_prebuilt_gzip_kernel(self):
        kernel = gzip.compress(b"prebuilt payload")
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "kernel.gz"
            path.write_bytes(kernel)
            args = SimpleNamespace(
                kernel_gzip=str(path),
                uefi=None,
                fd_base=None,
                fd_size=None,
            )
            self.assertEqual(build_kernel_payload(args, 0x40000000), (kernel, {}))

    def test_bootshim_copy_ranges_must_be_disjoint_or_identical(self):
        kernel_target = 0x40000000
        shim_size = 0x1000
        fd_size = 0x200000
        self.assertTrue(validate_bootshim_ranges(
            kernel_target, shim_size, fd_size, kernel_target + shim_size))
        self.assertFalse(validate_bootshim_ranges(
            kernel_target, shim_size, fd_size, 0x50000000))
        with self.assertRaisesRegex(ValueError, "partially overlaps"):
            validate_bootshim_ranges(
                kernel_target, shim_size, fd_size, kernel_target + shim_size + 0x1000)

    def test_fd_path_builds_gzip_and_rejects_partial_overlap(self):
        kernel_target = 0x40000000
        shim = bytearray(b"S" * 0x1000)
        shim[56:60] = b"ARM\x64"
        firmware = b"F" * 0x2000
        with tempfile.TemporaryDirectory() as temp:
            fd = Path(temp) / "firmware.fd"
            fd.write_bytes(firmware)
            args = SimpleNamespace(
                kernel_gzip=None,
                uefi=temp,
                fd=str(fd),
                fd_base=kernel_target + len(shim),
                fd_size=len(firmware),
            )
            with patch("unixnu.bootimg.compile_shim", return_value=shim):
                kernel, report = build_kernel_payload(args, kernel_target)
            expected = bytearray(shim)
            struct.pack_into("<Q", expected, 8, 0)
            struct.pack_into("<Q", expected, 24, 0xA)
            self.assertEqual(gzip.decompress(kernel), bytes(expected) + firmware)
            self.assertTrue(report["fd_load_in_place"])

            args.fd_base += 0x100
            with patch("unixnu.bootimg.compile_shim", return_value=shim):
                with self.assertRaisesRegex(ValueError, "partially overlaps"):
                    build_kernel_payload(args, kernel_target)

    def test_fd_size_must_match_bootshim_copy_granularity(self):
        with tempfile.TemporaryDirectory() as temp:
            fd = Path(temp) / "firmware.fd"
            fd.write_bytes(b"F" * 17)
            args = SimpleNamespace(
                kernel_gzip=None,
                uefi=temp,
                fd=str(fd),
                fd_base=0x40000000,
                fd_size=None,
            )
            with self.assertRaisesRegex(ValueError, "16-byte chunks"):
                build_kernel_payload(args, 0x40000000)

    def test_rejects_invalid_payload_and_ramdisk_table(self):
        with self.assertRaisesRegex(ValueError, "multiple of 512"):
            build_v4(boot_template(8192), b"", b"x", "init_boot")
        broken = bytearray(vendor_boot_fixture())
        struct.pack_into("<I", broken, 12288, 0xFFFFFFFF)
        with self.assertRaisesRegex(ValueError, "out of bounds"):
            normal_vendor_ramdisk_size(bytes(broken))


if __name__ == "__main__":
    unittest.main()
