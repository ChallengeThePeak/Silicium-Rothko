#!/bin/bash
# 判定实验：内存表压到 3 GiB，观察异常是否消失或下移
set -u
M=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$M" "$Q/MemoryMapLib.c.pre3g-$(date +%Y%m%d-%H%M%S)"
export PATH=/home/ubuntu/bin:$PATH

python3 - "$M" <<'PY'
import re, sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().splitlines(keepends=True)
out = []
hit = 0
for ln in lines:
    m = re.search(r'0x([0-9A-Fa-f]+),\s*0x[0-9A-Fa-f]+,\s*AddMem,\s*SYS_MEM', ln)
    if m and not ln.lstrip().startswith("//") and '"' in ln:
        base = int(m.group(1), 16)
        if base >= 0xC0000000:
            out.append("  // [k70u-3g 2026-11-02] held back for the top-region experiment\n")
            out.append("#" + ln.lstrip("\n").rstrip("\n") + "\n")
            hit += 1
            continue
    out.append(ln)
open(p, "w", encoding="utf-8").write("".join(out))
print("commented out", hit, "regions >= 3 GiB")
PY

echo "=== 剩余区域 ==="
rg -n 'AddMem, SYS_MEM' "$M" | rg -v '^\s*[0-9]+:\s*//' | head -40
