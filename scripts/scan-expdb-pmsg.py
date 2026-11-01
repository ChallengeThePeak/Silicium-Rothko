#!/usr/bin/env python3
"""在 expdb 里找 UEFI pstore 标记，并统计非零分布"""
import sys
from pathlib import Path

cands = [
    Path(r"I:\刷机\root\scrcpy-win64-v3.2\k70u-expdb-20261101-1106\expdb.raw.bin"),
]
markers = [b"K70U_UEFI_PSTORE_BEGIN", b"K70U-GCD", b"K70U-MMU", b"K70U-EXC", b"Project Silicium"]

for p in cands:
    if not p.exists():
        print(f"[缺失] {p}")
        continue
    data = p.read_bytes()
    print(f"=== {p}  {len(data)} bytes ===")

    # 非零分布（按 1 MiB 统计）
    chunk = 1 << 20
    nz = []
    for off in range(0, len(data), chunk):
        seg = data[off:off + chunk]
        if any(seg):
            nz.append(off)
    if nz:
        print(f"非零块数 {len(nz)} / {len(data)//chunk}，首块 {hex(nz[0])}，末块 {hex(nz[-1])}")
        print(f"非零区域合计 {len(nz)} MiB")
    else:
        print("整分区全零")

    for m in markers:
        idx = data.find(m)
        if idx < 0:
            print(f"  {m.decode():28s} 未找到")
        else:
            cnt = data.count(m)
            print(f"  {m.decode():28s} 首次偏移 0x{idx:x}  出现 {cnt} 次")
