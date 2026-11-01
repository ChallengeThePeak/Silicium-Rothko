#!/usr/bin/env python3
"""静态检查 DA 文件是否带 extensions / peek 能力"""
import hashlib
import re
from pathlib import Path

p = Path(r"C:\Users\Administrator\Documents\k70usprig预防针\DA_full_1.0_2.0_patched.bin")
d = p.read_bytes()
print(f"文件 {p.name}")
print(f"大小 {len(d)} bytes ({len(d)/1024:.0f} KiB)  sha256 {hashlib.sha256(d).hexdigest()}")
print(f"前 64 字节: {d[:64].hex()}")

strs = re.findall(rb"[\x20-\x7e]{6,}", d)
text = [s.decode() for s in strs]
print(f"可打印串 {len(text)} 条")

KEYS = ["extension", "Extension", "EXTENSION", "DALib", "dalib", "peek", "Peek",
        "PEEK", "memory", "Memory", "ReadMem", "read_mem", "get_ext", "custom"]
hits = {}
for s in text:
    for k in KEYS:
        if k in s:
            hits.setdefault(k, []).append(s[:90])

for k, v in hits.items():
    print(f"\n[{k}] {len(v)} 条")
    for s in v[:5]:
        print("   ", s)

print("\n=== 版本/标识串 ===")
for s in text:
    if re.search(r"DA_|DA BR|MTK_DA|v\d+\.\d+|1\.0\.2\.0|SPRIG|k70u", s, re.I) and len(s) < 80:
        print("   ", s)
