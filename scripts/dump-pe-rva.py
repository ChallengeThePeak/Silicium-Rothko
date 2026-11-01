#!/usr/bin/env python3
"""Dump a byte range of a PE32+ image by RVA.

llvm-objdump -s needs section names/offsets that are awkward to drive from a
shell one-liner, so this does the PE section mapping directly.
"""
import struct
import sys
import pathlib

efi = pathlib.Path(sys.argv[1])
rva = int(sys.argv[2], 0)
length = int(sys.argv[3], 0) if len(sys.argv) > 3 else 128

data = efi.read_bytes()

if data[:2] != b"MZ":
    raise SystemExit("not a PE image")
pe_off, = struct.unpack_from("<I", data, 0x3C)
if data[pe_off:pe_off + 4] != b"PE\0\0":
    raise SystemExit("bad PE signature")

coff = pe_off + 4
num_sections, = struct.unpack_from("<H", data, coff + 2)
opt_size, = struct.unpack_from("<H", data, coff + 16)
opt_off = coff + 20
magic, = struct.unpack_from("<H", data, opt_off)
if magic == 0x20B:
    image_base, = struct.unpack_from("<Q", data, opt_off + 24)
elif magic == 0x10B:
    image_base, = struct.unpack_from("<I", data, opt_off + 28)
else:
    raise SystemExit(f"unknown optional header magic {magic:#x}")

sec_off = opt_off + opt_size
sections = []
for i in range(num_sections):
    o = sec_off + i * 40
    name = data[o:o + 8].rstrip(b"\0").decode("ascii", "replace")
    vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", data, o + 8)
    sections.append((name, vaddr, vsize, rawptr, rawsize))

print(f"file       : {efi.name}")
print(f"image base : {image_base:#x}")
for name, vaddr, vsize, rawptr, rawsize in sections:
    print(f"  {name:<10} RVA {vaddr:#08x} vsize {vsize:#x} raw {rawptr:#x}+{rawsize:#x}")

for name, vaddr, vsize, rawptr, rawsize in sections:
    if vaddr <= rva < vaddr + max(vsize, rawsize):
        off = rawptr + (rva - vaddr)
        chunk = data[off:off + length]
        print(f"\nRVA {rva:#x} in {name}: raw offset {off:#x}")
        print("  hex :", chunk.hex())
        printable = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        print("  text:", printable)
        # Null-terminated strings inside the range.
        for s in chunk.split(b"\0"):
            if len(s) >= 4:
                print("  str :", repr(s))
        break
else:
    print(f"\nRVA {rva:#x} not found in any section")
