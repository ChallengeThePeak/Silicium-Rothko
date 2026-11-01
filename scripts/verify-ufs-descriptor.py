#!/usr/bin/env python3
"""Confirm the compiled SEC image carries the fixed UFS HCI descriptor length.

gMemoryDescriptor is a static array of EFI_MEMORY_REGION_DESCRIPTOR:
    char *Name;              // 8 bytes
    EFI_PHYSICAL_ADDRESS Address;   // 8 bytes
    UINT64 Length;           // 8 bytes
    ...
So scanning .data for the 8-byte little-endian UFS HCI address and reading the
next 8 bytes yields the compiled length.
"""
import struct
import sys
import pathlib

EFI = pathlib.Path(sys.argv[1])
data = EFI.read_bytes()

UFS_ADDR = 0x112B0000
needle = struct.pack("<Q", UFS_ADDR)

print(f"file: {EFI.name} ({len(data)} bytes)")

hits = []
start = 0
while True:
    i = data.find(needle, start)
    if i < 0:
        break
    hits.append(i)
    start = i + 1

if not hits:
    print("UFS HCI address 0x112B0000 not found as a u64 in the image")
    sys.exit(1)

for off in hits:
    length, = struct.unpack_from("<Q", data, off + 8)
    aligned = (length % 0x1000) == 0
    print(f"  @{off:#x}: address={UFS_ADDR:#x} length={length:#x} "
          f"{'OK (page aligned)' if aligned else 'FAIL (not page aligned)'}")

ok = any(struct.unpack_from("<Q", data, off + 8)[0] == 0x3000 for off in hits)
print()
print("RESULT:", "PASS - compiled length is 0x3000" if ok else "FAIL - expected 0x3000")
sys.exit(0 if ok else 1)
