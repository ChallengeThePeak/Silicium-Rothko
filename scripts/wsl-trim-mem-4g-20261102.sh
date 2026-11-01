#!/bin/bash
# A 方案：内存表裁到 4 GiB 以内；顺手修正 DEBUG 里的字面 \n
set -u
M=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$M" "$Q/MemoryMapLib.c.pre4g-$(date +%Y%m%d-%H%M%S)"
export PATH=/home/ubuntu/bin:$PATH

python3 - "$M" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "k70u-lo4g" in s:
    print("already patched"); raise SystemExit

# 跨界段：截到 4 GiB
old28 = '{"Free 28", 0xFFFFF000, 0xBFFFF000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},'
new28 = ('  // [k70u-lo4g 2026-11-02] Clipped at 4 GiB: the DXE pool took a block from the\n'
         '  // 13 GiB range and the store raised an address size fault, so keep every\n'
         '  // region inside the range the firmware demonstrably reaches.\n'
         '  {"Free 28", 0xFFFFF000, 0x00001000, AddMem, SYS_MEM, SYS_MEM_TESTED, Conv, WRITE_BACK_XN},')
if old28 not in s:
    sys.exit("Free 28 anchor missing")
s = s.replace(old28, new28, 1)

# 两段超 4 GiB：注释掉
for name, base in (("Free 29", "0x1C0000000"), ("Free 30", "0x33FE41000")):
    hits = [ln for ln in s.splitlines() if '"%s"' % name in ln and base in ln]
    if len(hits) != 1:
        sys.exit("anchor missing for " + name)
    line = hits[0]
    s = s.replace(line, "  // [k70u-lo4g 2026-11-02] Above 4 GiB, temporarily excluded:\n  //" + line.strip(), 1)

open(p, "w", encoding="utf-8").write(s)
print("memory map trimmed")
PY

echo "=== 改后表尾 ==="
rg -n "k70u-lo4g|Free 2[89]|Free 30" "$M" | head -10

echo
echo "=== 修正 DEBUG 里的字面 \\n ==="
T=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c
python3 - "$T" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
n = s.count('\\\\n')
s = s.replace('\\\\n', '\\n')
open(p, "w", encoding="utf-8").write(s)
print("replaced", n)
PY
rg -n "K70U-EL: CurrentEL" "$T" | head -2
