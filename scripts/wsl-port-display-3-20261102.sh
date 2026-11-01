#!/bin/bash
# 恢复被写坏的两个文件并正确重做插入
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
Q=/home/ubuntu/quarantine

echo "=== 恢复 ==="
cp -f "$(ls -t "$Q"/DXE.inc.orig-* | head -1)" "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc"
cp -f "$(ls -t "$Q"/rothko.dsc.orig-* | head -1)" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"
for f in "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"; do
  printf "%-20s LF=%s 行数=%s\n" "$(basename $f)" "$(tr -cd '\n' < "$f" | wc -c)" "$(wc -l < "$f")"
done

echo
echo "=== 正确插入 ==="
python3 - <<'PY'
import os
U = "/home/ubuntu/rothko-upstream-20261102/uefi-full"

def insert_after(path, matcher, new_lines):
    raw = open(path, "rb").read().decode("utf-8", "surrogateescape")
    nl = "\r\n" if "\r\n" in raw else "\n"
    lines = raw.split(nl)
    if any("RothkoDisplayDxe.inf" in l or "PcdFrameBufferWidth" in l for l in lines):
        print("already present:", os.path.basename(path)); return
    for i, l in enumerate(lines):
        if matcher(l):
            lines[i+1:i+1] = new_lines
            open(path, "wb").write(nl.join(lines).encode("utf-8", "surrogateescape"))
            print("ok:", os.path.basename(path), "at line", i+2); return
    print("!! matcher not found:", path)

INF = "  INF Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf"

insert_after(
    f"{U}/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc",
    lambda l: "MdeModulePkg/Universal/PrintDxe/PrintDxe.inf" in l,
    [INF],
)

insert_after(
    f"{U}/Platforms/Xiaomi/rothkoPkg/rothko.dsc",
    lambda l: "PcdDriverHealthConfigureForm" in l,
    [
      "  #",
      "  # [k70u-fix 2026-11-02] Panel geometry validated on dali (MT6991) and on",
      "  # the stock LK handoff for rothko: DSC + DSI command mode, 1220x2712, 32bpp.",
      "  # Stride is the pitch the OVL layer actually uses (1248).",
      "  # Delay 0: the framebuffer console must not slow the log down.",
      "  #",
      "  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferWidth|1220",
      "  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferHeight|2712",
      "  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferColorDepth|32",
      "  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferStride|1248",
      "  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferDelay|0",
    ],
)
PY

echo
echo "=== 校验三个文件 ==="
for f in "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$U/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"; do
  printf "%-16s 行数=%s  RothkoDisplay=%s\n" "$(basename $f)" "$(wc -l < "$f")" "$(rg -c 'RothkoDisplayDxe|PcdFrameBufferWidth' "$f" || echo 0)"
done
