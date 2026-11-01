#!/bin/bash
# 关闭 Driver Health 检查（PcdDriverHealthConfigureForm = ZeroGuid）
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/rothko.dsc
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$F" "$Q/rothko.dsc.orig-$(date +%Y%m%d-%H%M%S)"

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "PcdDriverHealthConfigureForm" in s:
    print("already set"); raise SystemExit

anchor = "  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemBoardModel|\"rothko\""
if anchor not in s:
    sys.exit("anchor missing")
add = anchor + """
  #
  # [k70u-fix 2026-11-02] BDS asserts at BmDriverHealth.c(553) because the FV has no
  # SetupBrowserDxe, so gEfiFormBrowser2ProtocolGuid is absent. UEFI provides this
  # documented switch: a zero PcdDriverHealthConfigureForm disables the check.
  #
  gEfiMdeModulePkgTokenSpaceGuid.PcdDriverHealthConfigureForm|{0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0}"""
s = s.replace(anchor, add, 1)
open(p, "w", encoding="utf-8").write(s)
print("pcd added")
PY

export PATH=/home/ubuntu/bin:$PATH
rg -n "PcdDriverHealthConfigureForm" "$F" | head -3
