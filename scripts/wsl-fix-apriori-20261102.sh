#!/bin/bash
# 从 APRIORI 移除 BdsDxe，让它按 FV 顺序在 HiiDatabaseDxe 之后调度
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$F" "$Q/APRIORI.inc.orig-$(date +%Y%m%d-%H%M%S)"

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().splitlines(keepends=True)
out = []
removed = False
for ln in lines:
    if "BdsDxe/BdsDxe.inf" in ln and not ln.lstrip().startswith("#"):
        out.append("  # [k70u-fix 2026-11-02] BdsDxe must NOT be in APRIORI: APRIORI drivers are\n")
        out.append("  # dispatched before every other driver, so BdsDxe ran before HiiDatabaseDxe\n")
        out.append("  # and UefiHiiServicesLib's constructor asserted at UefiHiiServicesLib.c(82).\n")
        out.append("  # Left in FV order instead, where HiiDatabaseDxe precedes it.\n")
        out.append("#" + ln.rstrip("\n") + "\n")
        removed = True
    else:
        out.append(ln)
open(p, "w", encoding="utf-8").write("".join(out))
print("removed" if removed else "not found")
PY

echo "=== 修改后 ==="
cat "$F"
