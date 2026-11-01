#!/bin/bash
# 补回 GIC Redistributors 行尾的逗号（它原本是数组末项）
set -u
export PATH=/home/ubuntu/bin:$PATH
M=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c

python3 - "$M" <<'PY'
import sys
p = sys.argv[1]
raw = open(p, "rb").read().decode("utf-8", "surrogateescape")
nl = "\r\n" if "\r\n" in raw else "\n"
lines = raw.split(nl)
fixed = False
for i, l in enumerate(lines):
    if '"GIC Redistributors"' in l and l.rstrip().endswith("}"):
        lines[i] = l.rstrip() + ","
        fixed = True
        print("fixed comma at line", i+1)
open(p, "wb").write(nl.join(lines).encode("utf-8", "surrogateescape"))
if not fixed:
    print("no change needed")
PY

echo "=== 数组尾部 ==="
rg -n -A3 "GIC Redistributors" "$M" | head -6
