#!/usr/bin/env python3
"""Dump every field of an AVB vbmeta header so offsets can be cross-checked
against the spec instead of guessed.

Header (big-endian), per external/avb/libavb/avb_vbmeta_image.h:
  magic[4] @0x00, required_major @0x04, required_minor @0x08,
  auth_block_size @0x0C, auxiliary_block_size @0x14,
  algorithm_type @0x1C,
  hash_offset @0x20, hash_size @0x28,
  signature_offset @0x30, signature_size @0x38,
  public_key_offset @0x40, public_key_size @0x48,
  public_key_metadata_offset @0x50, public_key_metadata_size @0x58,
  descriptors_offset @0x60, descriptors_size @0x68,
  rollback_index @0x70, flags @0x78,
  rollback_index_location @0x7C, release_string @0x80[48]
"""
import struct
import sys
import pathlib

src = pathlib.Path(sys.argv[1])
d = src.read_bytes()

print(f"file: {src} ({len(d)} bytes)")
if d[:4] != b"AVB0":
    raise SystemExit(f"bad magic {d[:4]!r}")

u32 = lambda o: struct.unpack_from(">I", d, o)[0]
u64 = lambda o: struct.unpack_from(">Q", d, o)[0]

auth = u64(0x0C)
aux = u64(0x14)

fields = [
    ("required_major", u32(0x04)),
    ("required_minor", u32(0x08)),
    ("auth_block_size", auth),
    ("auxiliary_block_size", aux),
    ("algorithm_type", u32(0x1C)),
    ("hash_offset", u64(0x20)),
    ("hash_size", u64(0x28)),
    ("signature_offset", u64(0x30)),
    ("signature_size", u64(0x38)),
    ("public_key_offset", u64(0x40)),
    ("public_key_size", u64(0x48)),
    ("public_key_metadata_offset", u64(0x50)),
    ("public_key_metadata_size", u64(0x58)),
    ("descriptors_offset", u64(0x60)),
    ("descriptors_size", u64(0x68)),
    ("rollback_index", u64(0x70)),
    ("flags", u32(0x78)),
    ("rollback_index_location", u32(0x7C)),
]
for name, val in fields:
    if isinstance(val, int) and "offset" not in name and "size" not in name:
        print(f"  {name:<28} {val} ({val:#x})")
    else:
        print(f"  {name:<28} {val} ({val:#x})" if isinstance(val, int) else f"  {name:<28} {val}")

release = d[0x80:0x80 + 48].split(b"\x00")[0]
print(f"  {'release_string':<28} {release!r}")

total = 0x80 + auth + aux
print(f"\nheader-computed total: {total} ({total:#x}); file: {len(d)}")
if len(d) != total:
    print("  NOTE: trailing bytes present, or the image is padded")
