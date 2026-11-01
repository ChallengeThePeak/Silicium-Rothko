#!/bin/bash
# 把 UEFI 图形菜单接进 FV：BootManagerMenuApp + SetupBrowserDxe，并应用上游的 Boot-Manager 补丁
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
Q=/home/ubuntu/quarantine

echo "=== 1) 应用上游 Boot-Manager.patch 到 Mu_Basecore ==="
cd "$U/Mu_Basecore" || exit 1
if rg -q "UEFI Misc Device" MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenu.c 2>/dev/null; then
  echo "  补丁已应用，跳过"
else
  git apply --check "$U/Resources/MuPatches/Boot-Manager.patch" 2>&1 | head -5 && \
    git apply "$U/Resources/MuPatches/Boot-Manager.patch" && echo "  补丁应用成功" || echo "  补丁应用失败（继续，不影响菜单本体）"
fi
git status --short | head -5

echo
echo "=== 2) 把菜单与 SetupBrowser 加进 FV（rothkoPkg/Include/DXE.inc）==="
DXE="$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc"
cp -f "$DXE" "$Q/DXE.inc.pre-menu-$(date +%Y%m%d-%H%M%S)"
python3 - "$DXE" <<'PY'
import sys
p = sys.argv[1]
raw = open(p, "rb").read().decode("utf-8", "surrogateescape")
nl = "\r\n" if "\r\n" in raw else "\n"
lines = raw.split(nl)
add = [
    "  #",
    "  # [k70u-fix 2026-11-02] The graphical boot manager. BDS looks the menu up by",
    "  # GUID through PcdBootManagerMenuFile, and that GUID is this module's",
    "  # FILE_GUID (EEC25BDC-67F2-4D95-B1D5-F81B2039D11D), so putting the INF in",
    "  # the FV is what makes the menu appear. SetupBrowserDxe provides the",
    "  # FormBrowser2 protocol the menu needs.",
    "  #",
    "  INF MdeModulePkg/Application/BootManagerMenuApp/BootManagerMenuApp.inf",
    "  INF MdeModulePkg/Universal/SetupBrowserDxe/SetupBrowserDxe.inf",
]
if any("BootManagerMenuApp.inf" in l for l in lines):
    print("already present")
else:
    anchor = "  INF MdeModulePkg/Universal/BdsDxe/BdsDxe.inf"
    idx = next((i for i, l in enumerate(lines) if anchor in l), None)
    if idx is None:
        sys.exit("anchor missing")
    lines[idx+1:idx+1] = add
    open(p, "wb").write(nl.join(lines).encode("utf-8", "surrogateescape"))
    print("menu INFs added to DXE.inc")
PY

echo
echo "=== 3) 校验 ==="
rg -n "BootManagerMenuApp|SetupBrowserDxe" "$DXE" | head -4
rg -n "PcdBootManagerMenuFile" "$U/Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc" | head -3
