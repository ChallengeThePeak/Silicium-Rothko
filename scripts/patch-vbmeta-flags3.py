#!/usr/bin/env python3
"""Create a separate AVB vbmeta copy with verification and hashtree disabled."""
from pathlib import Path
import struct, sys
src=Path(sys.argv[1]); dst=Path(sys.argv[2])
if dst.exists(): raise SystemExit(f"refusing to overwrite {dst}")
data=bytearray(src.read_bytes())
if data[:4] != b"AVB0": raise SystemExit(f"bad vbmeta magic: {data[:4]!r}")
off=0x78
old=struct.unpack_from(">I",data,off)[0]
new=old | 0x3
struct.pack_into(">I",data,off,new)
dst.parent.mkdir(parents=True,exist_ok=True); dst.write_bytes(data)
check=struct.unpack_from(">I",dst.read_bytes(),off)[0]
changed=[i for i,(a,b) in enumerate(zip(src.read_bytes(),data)) if a!=b]
print(f"flags {old:#x} -> {check:#x}; bytes_changed={changed}; output={dst} bytes={len(data)}")
