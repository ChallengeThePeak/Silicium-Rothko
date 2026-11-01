#!/bin/bash
# 修正 rothko 内存表：资源描述 HOB 属性改为测试过的系统内存（P|I|T）
set -u
M=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$M" "$Q/MemoryMapLib.c.orig-$(date +%Y%m%d-%H%M%S)"

python3 - "$M" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "SYS_MEM_TESTED" in s:
    print("already patched"); raise SystemExit
banner = '''#include <Library/MemoryMapLib.h>

//
// [k70u-fix 2026-11-02] CoreInitializeMemoryServices (Gcd.c) requires the resource
// descriptor HOB that covers the PHIT free range to carry EXACTLY
// PRESENT|INITIALIZED|TESTED after masking. SYS_MEM_CAP_XN additionally sets
// UNCACHEABLE/WC/WT/WB/EXECUTION_PROTECTED, so the strict equality failed and DXE
// asserted at Gcd.c(2448) with Found=0. Cacheability and XN keep coming from the
// last two table columns, which drive the MMU setup and are unaffected.
//
#define SYS_MEM_TESTED (PRESENT | INITIALIZED | TESTED)
'''
s = s.replace("#include <Library/MemoryMapLib.h>\n", banner, 1)
n = s.count("SYS_MEM_CAP_XN")
s = s.replace("SYS_MEM_CAP_XN", "SYS_MEM_TESTED")
open(p, "w", encoding="utf-8").write(s)
print("replaced", n, "occurrences")
PY

echo "=== 结果确认 ==="
grep -c "SYS_MEM_TESTED" "$M"
sed -n '1,26p' "$M"
