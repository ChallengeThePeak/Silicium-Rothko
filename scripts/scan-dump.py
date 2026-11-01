#!/usr/bin/env python3
"""通用转储扫描：pstore 标记 / MTK AEE 结构 / 非零分布"""
import sys
from pathlib import Path

MARKERS = [
    b"K70U_UEFI_PSTORE_BEGIN", b"K70U-GCD", b"K70U-MMU", b"K70U-EXC",
    b"Project Silicium", b"DBGC",
    b"AEE0DEAD", b"TFA_DEBUG_BUF", b"blackbox", b"BOOT_REASON",
    b"WDT", b"wdt", b"Kernel panic", b"abort",
]


def scan(path: Path) -> None:
    data = path.read_bytes()
    print(f"=== {path.name}  {len(data)} bytes ({len(data)/1048576:.2f} MiB) ===")

    chunk = 1 << 20
    nz = [off for off in range(0, len(data), chunk) if any(data[off:off + chunk])]
    if nz:
        print(f"非零块 {len(nz)}/{len(data)//chunk}  首 0x{nz[0]:x}  末 0x{nz[-1]:x}"
              f"  合计 {len(nz)} MiB")
    else:
        print("整区全零")

    print(f"前 16 字节: {data[:16].hex()}")
    for m in MARKERS:
        c = data.count(m)
        if c:
            print(f"  {m.decode('latin1'):24s} {c:5d} 次  首偏移 0x{data.find(m):x}")
    print()


if __name__ == "__main__":
    targets = [Path(a) for a in sys.argv[1:]]
    if not targets:
        targets = sorted(Path(r"D:\漏洞\UNIXNU\适配K70U\logs").glob("blackbox*.img"))
    if not targets:
        print("没有可扫描的文件，传入路径或把文件放到 logs\\blackbox*.img")
        raise SystemExit(1)
    for t in targets:
        if t.exists():
            scan(t)
        else:
            print(f"[缺失] {t}")
