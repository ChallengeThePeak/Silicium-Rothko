#!/usr/bin/env python3
"""Disable AVB verification in a vbmeta image by setting the flags field.

  flags bit 0 (0x1) = HASHTREE_DISABLED
  flags bit 1 (0x2) = VERIFICATION_DISABLED

`flags = 0x2` makes an AVB-aware bootloader skip verification of every
partition chained from this vbmeta. It does NOT require re-signing: the header
hash covers the descriptors, and the flags field sits before them, but LK only
consults flags to decide whether to verify at all, so a mismatching signature
is never checked.

Only the 4 bytes at 0x78 are rewritten. The source file is never modified.
"""
import struct
import sys
import pathlib

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])

FLAGS_OFF = 0x78
VERIFICATION_DISABLED = 0x2

data = bytearray(src.read_bytes())

if len(data) < FLAGS_OFF + 4:
    raise SystemExit(f"{src}: too small to be a vbmeta image ({len(data)} bytes)")
if data[:4] != b"AVB0":
    raise SystemExit(f"{src}: bad magic {data[:4]!r}, expected b'AVB0'")

alg, = struct.unpack_from(">I", data, 0x1C)
old, = struct.unpack_from(">I", data, FLAGS_OFF)
new = old | VERIFICATION_DISABLED
struct.pack_into(">I", data, FLAGS_OFF, new)

dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_bytes(data)

check, = struct.unpack_from(">I", dst.read_bytes(), FLAGS_OFF)

print(f"source        : {src}")
print(f"algorithm     : {alg}")
print(f"flags {old:#018x} -> {check:#018x}")
print(f"  verification_disabled : {bool(check & 0x2)}")
print(f"  hashtree_disabled     : {bool(check & 0x1)}")
print(f"written       : {dst} ({dst.stat().st_size} bytes)")

# Prove only those four bytes moved.
orig = src.read_bytes()
diff = [i for i in range(min(len(orig), len(data))) if orig[i] != data[i]]
print(f"bytes changed : {len(diff)} at offsets {[hex(i) for i in diff]}")
