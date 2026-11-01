#!/bin/bash
# DTB 区域改名 "LK DTB" 并改为保留区（与已验证的旧树一致）
set -u
export PATH=/home/ubuntu/bin:$PATH
M=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c
Q=/home/ubuntu/quarantine
cp -f "$M" "$Q/MemoryMapLib.c.pre-lkdtb-$(date +%Y%m%d-%H%M%S)"

python3 - "$M" <<'PY'
import sys
p = sys.argv[1]
raw = open(p, "rb").read().decode("utf-8", "surrogateescape")
nl = "\r\n" if "\r\n" in raw else "\n"
lines = raw.split(nl)
old = None
for i, l in enumerate(lines):
    if '"Incoming DTB"' in l:
        old = i
        break
if old is None:
    print("Incoming DTB not found"); raise SystemExit
print("old:", lines[old])

indent = lines[old][:len(lines[old]) - len(lines[old].lstrip())]
lines[old] = (
    indent + '// [k70u-fix 2026-11-02] Renamed to the name RothkoDisplayDxe looks up\n'
    + indent + '// ("LK DTB"), and made reserved: LK hands the live device tree over in x0\n'
    + indent + '// and the driver reads it, so GCD must not hand this range out. The old\n'
    + indent + '// tree had it as MEM_RES/Reserv at the same base and size.\n'
    + indent + '{"LK DTB", 0x47C80000, 0x00400000, AddMem, MEM_RES, SYS_MEM_TESTED, Reserv, WRITE_BACK_XN},'
)
open(p, "wb").write(nl.join(lines).encode("utf-8", "surrogateescape"))
print("new:", lines[old])
PY
