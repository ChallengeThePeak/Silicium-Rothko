#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
DXE="$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc"

python3 - "$DXE" <<'PY'
import sys
p = sys.argv[1]
raw = open(p, "rb").read().decode("utf-8", "surrogateescape")
nl = "\r\n" if "\r\n" in raw else "\n"
lines = raw.split(nl)
add = [
    "#",
    "# [k70u-fix 2026-11-02] The graphical boot manager. BDS looks the menu up by",
    "# GUID through PcdBootManagerMenuFile, and that GUID is this module's",
    "# FILE_GUID (EEC25BDC-67F2-4D95-B1D5-F81B2039D11D), so putting the INF in",
    "# the FV is what makes the menu appear. SetupBrowserDxe provides the",
    "# FormBrowser2 protocol the menu needs.",
    "#",
    "INF MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenuApp.inf",
    "INF MdeModulePkg/Universal/SetupBrowserDxe/SetupBrowserDxe.inf",
]
if any("BootManagerMenuApp.inf" in l for l in lines):
    print("already present")
else:
    anchor = "INF MdeModulePkg/Universal/BdsDxe/BdsDxe.inf"
    idx = next((i for i, l in enumerate(lines) if l.strip() == anchor), None)
    if idx is None:
        sys.exit("anchor missing")
    lines[idx+1:idx+1] = add
    open(p, "wb").write(nl.join(lines).encode("utf-8", "surrogateescape"))
    print("menu INFs added after BdsDxe")
PY

echo "=== 校验 ==="
rg -n "BootManagerMenuApp|SetupBrowserDxe|BdsDxe" "$DXE" | head -6
