#!/bin/bash
set -u
P=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c
echo "=== 现有 include ==="
head -12 "$P"
python3 - "$P" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "<Library/ArmLib.h>" in s:
    print("ArmLib.h 已存在"); raise SystemExit
lines = s.splitlines(keepends=True)
for i, ln in enumerate(lines):
    if ln.strip().startswith("#include"):
        lines.insert(i, "#include <Library/ArmLib.h>\n")
        break
open(p, "w", encoding="utf-8").write("".join(lines))
print("ArmLib.h 已插入")
PY
echo "=== 修改后 ==="
head -12 "$P"
