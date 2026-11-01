#!/bin/bash
# 按平台包前缀注册 RothkoDisplayDxe：DSC [Components] + FDF 的 DXE.inc/APRIORI.inc
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

python3 - <<'PY'
import os
U = "/home/ubuntu/rothko-upstream-20261102/uefi-full"
INF_FDF = "  INF rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf"

def edit(path, fn):
    raw = open(path, "rb").read().decode("utf-8", "surrogateescape")
    nl = "\r\n" if "\r\n" in raw else "\n"
    lines = raw.split(nl)
    out = fn(lines)
    if out is None:
        return
    open(path, "wb").write(nl.join(out).encode("utf-8", "surrogateescape"))
    print("patched", os.path.basename(path))

# 1) FDF 的两个 include：换成平台包前缀
def fix_fdf(lines):
    changed = False
    for i, l in enumerate(lines):
        if "RothkoDisplayDxe.inf" in l and "Platforms/Xiaomi" in l:
            lines[i] = INF_FDF
            changed = True
    return lines if changed else None

edit(f"{U}/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc", fix_fdf)
edit(f"{U}/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc", fix_fdf)

# 2) rothko.dsc 增加 [Components]
def fix_dsc(lines):
    if any("[Components]" in l for l in lines):
        return None
    block = [
      "[Components]",
      "  #",
      "  # MT6989 display: inherits LK's OVL/DSI chain and drives command-mode frame",
      "  # submission (the dali approach). It is the only GOP producer, so the",
      "  # generic SimpleFbDxe stays excluded via USE_CUSTOM_DISPLAY_DRIVER = 1.",
      "  #",
      "  rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf",
      "",
    ]
    # 放在 !include UniXNUComponents.dsc.inc 之前
    for i, l in enumerate(lines):
        if l.startswith("!include rothkoPkg/UniXNUComponents.dsc.inc"):
            return lines[:i] + block + lines[i:]
    return lines + block

edit(f"{U}/Platforms/Xiaomi/rothkoPkg/rothko.dsc", fix_dsc)
PY

echo
echo "=== 校验 ==="
rg -n "RothkoDisplayDxe" "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$U/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"
