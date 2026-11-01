#!/usr/bin/env python3
"""Parse the rothko FD: FV header -> first FFS -> PE32 -> entry point.

The BootShim jumps to FD_BASE, which is the firmware volume header, not code.
EDK II writes a branch into the FV zero vector for exactly this reason; this
script confirms where that branch goes and whether it lands on the SEC module.
"""
import struct
import sys
import pathlib
import uuid

FD = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                  "/home/ubuntu/rothko/analyse/fd.bin")

data = FD.read_bytes()
print(f"file: {FD.name} ({len(data)} bytes)")

# FV header lives at offset 0x28 of the FD (after the 16-byte zero vector and
# the filesystem GUID).
sig_off = data.find(b"_FVH")
if sig_off < 0:
    raise SystemExit("no _FVH found")
fv_base = sig_off - 0x28

fv_len, = struct.unpack_from("<Q", data, fv_base + 0x20)
attrs, = struct.unpack_from("<I", data, fv_base + 0x2C)
hdr_len, = struct.unpack_from("<H", data, fv_base + 0x30)
checksum, = struct.unpack_from("<H", data, fv_base + 0x32)
fs_guid = uuid.UUID(bytes_le=data[fv_base + 0x10:fv_base + 0x20])

print(f"FV base      : {fv_base:#x}")
print(f"FV length    : {fv_len:#x}")
print(f"header length: {hdr_len:#x}")
print(f"filesystem   : {fs_guid}")

# Zero vector: on ARM EDK II this holds a branch to the reset vector / SEC.
zv = data[fv_base:fv_base + 16]
print(f"zero vector  : {zv.hex()}")

if zv[3] & 0xFC == 0x14:   # B <imm26>
    imm = struct.unpack_from("<I", zv, 0)[0]
    imm &= 0x03FFFFFF
    if imm & 0x02000000:
        imm -= 0x04000000
    target = fv_base + imm * 4
    print(f"  -> branch to {target:#x} (FV+{target - fv_base:#x})")
else:
    print("  -> not a branch instruction")

# Walk FFS files.
print("\nFFS files:")
off = fv_base + hdr_len
end = fv_base + fv_len
while off + 24 <= end:
    name = data[off:off + 16]
    if name == b"\xff" * 16:
        break
    ftype = data[off + 18]
    fsize = data[off + 20] | (data[off + 21] << 8) | (data[off + 22] << 16)
    if fsize < 24:
        break

    ui = ""
    s = off + 24
    while s + 4 <= off + fsize:
        ssize = data[s] | (data[s + 1] << 8) | (data[s + 2] << 16)
        stype = data[s + 3]
        if ssize < 4:
            break
        if stype == 0x15:
            ui = data[s + 4:s + ssize].decode("utf-16-le", "replace").rstrip("\x00")
            break
        s += (ssize + 3) & ~3

    if ui:
        print(f"  {off:#x} type={ftype:#04x} size={fsize:#x} {ui}")
    off += (fsize + 7) & ~7
