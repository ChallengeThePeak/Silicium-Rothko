#!/usr/bin/env python3
"""Print the symbol (and object file) that contains a given RVA, from an EDK II .map.

The GNU/LLVM map emitted by EDK II lists  "ADDRESS SIZE ALIGN <path or symbol>"
lines; symbol rows are indented deeper and follow the object file row they
belong to. Usage: map-whereis.py <map> <rva-hex>
"""
import re
import sys

path = sys.argv[1]
target = int(sys.argv[2], 0)

rows = []
cur_obj = None
for line in open(path, errors="replace"):
    m = re.match(r"^([0-9a-f]{8}) ([0-9a-f]{8})\s+\d+\s+(\S.*)$", line.rstrip())
    if not m:
        continue
    addr, size, rest = int(m.group(1), 16), int(m.group(2), 16), m.group(3).strip()
    if rest.startswith("/"):
        cur_obj = rest.rsplit("/", 1)[-1]
        rows.append((addr, size, None, cur_obj))
    else:
        rows.append((addr, size, rest, cur_obj))

sym = [r for r in rows if r[2] and r[0] <= target]
sym.sort(key=lambda r: r[0])
if not sym:
    raise SystemExit("no symbol below target")

for r in sym[-3:]:
    print(f"0x{r[0]:06x} +0x{r[1]:<6x} {r[2]:<40} {r[3]}")

best = sym[-1]
print(f"\ncontaining symbol : {best[2]}  (+0x{target - best[0]:x})")
print(f"object            : {best[3]}")

after = [r for r in rows if r[2] and r[0] > target][:3]
for r in after:
    print(f"next symbol       : 0x{r[0]:06x} {r[2]}")
