#!/usr/bin/env python3
"""Parse an EDK II firmware volume and list the FFS files it contains.

Used to confirm which drivers actually made it into the shipped FD, without
relying on the build log (the build log lists modules even when a later stage
silently drops them from the FV).

Read-only.
"""
import struct
import sys
import pathlib
import uuid

FD = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                  "/mnt/d/漏洞/UNIXNU/适配K70U/../适配K70U/work/rothko-fd.bin")


def guid_str(raw: bytes) -> str:
    return str(uuid.UUID(bytes_le=raw))


def parse_fv(data: bytes, base: int, label: str) -> None:
    if data[base:base + 4] != b"_FVH":
        # Some FVs start with a zero-vector header; look for the signature.
        idx = data.find(b"_FVH", base, base + 0x100)
        if idx < 0:
            print(f"  {label}: no _FVH signature at {base:#x}")
            return
        base = idx - 0x28
    fv_len, = struct.unpack_from("<Q", data, base + 0x20)
    attrs, = struct.unpack_from("<I", data, base + 0x2C)
    hdr_len, = struct.unpack_from("<H", data, base + 0x30)
    print(f"  {label}: FV at {base:#x}, length {fv_len:#x}, header {hdr_len:#x}")

    off = base + hdr_len
    end = base + fv_len
    count = 0
    while off + 24 <= end:
        name = data[off:off + 16]
        if name == b"\xff" * 16:
            # Erased region: advance to the next 8-byte alignment and rescan.
            off = (off + 8) & ~7
            nxt = data.find(b"_FVH", off, end)
            if nxt < 0:
                break
            off = nxt - 0x28
            continue

        ftype = data[off + 18]
        fsize = data[off + 20] | (data[off + 21] << 8) | (data[off + 22] << 16)
        if fsize < 24:
            break

        # Section: look for the UI section (0x15) holding the module name.
        ui = ""
        s = off + 24
        send = off + fsize
        while s + 4 <= send:
            ssize = data[s] | (data[s + 1] << 8) | (data[s + 2] << 16)
            stype = data[s + 3]
            if ssize < 4:
                break
            if stype == 0x15:  # EFI_SECTION_USER_INTERFACE
                raw = data[s + 4:s + ssize]
                ui = raw.decode("utf-16-le", errors="replace").rstrip("\x00")
                break
            s += (ssize + 3) & ~3

        if ui:
            print(f"    [{ftype:#04x}] {guid_str(name)}  {ui}")
            count += 1
        off += (fsize + 7) & ~7

    print(f"    ({count} named FFS files)")


data = FD.read_bytes()
print(f"file: {FD.name} ({len(data):#x} bytes)")

# The FD starts with a 0x48-byte vector, then the FV.
parse_fv(data, 0x48 if data[0x40:0x44] == b"_FVH" else 0, "FV")
