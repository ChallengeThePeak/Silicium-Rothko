#!/bin/bash
# 补上 DXE.inc 与 rothko.dsc 的挂载（按行定位，兼容 CRLF）
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

python3 - <<'PY'
import io, os, re
U = "/home/ubuntu/rothko-upstream-20261102/uefi-full"

def insert_after_line(path, matcher, new_lines):
    raw = open(path, "rb").read().decode("utf-8", "surrogateescape")
    nl = "\r\n" if "\r\n" in raw else "\n"
    lines = raw.split(nl)
    if any("RothkoDisplayDxe.inf" in l for l in lines):
        print("already mounted:", os.path.basename(path)); return
    for i, l in enumerate(lines):
        if matcher(l):
            lines[i+1:i+1] = [x + nl for x in new_lines]
            open(path, "wb").write("".join(lines).encode("utf-8", "surrogateescape"))
            print("mounted at line", i+1, "in", os.path.basename(path)); return
    print("!! matcher not found in", path)

INF = "  INF Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.inf"

insert_after_line(
    f"{U}/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc",
    lambda l: "MdeModulePkg/Universal/PrintDxe/PrintDxe.inf" in l,
    [INF],
)

insert_after_line(
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
echo "=== 校验 ==="
rg -n "RothkoDisplayDxe.inf" "$U/Platforms/Xiaomi/rothkoPkg/Include/DXE.inc" "$U/Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc"
rg -n "PcdFrameBuffer" "$U/Platforms/Xiaomi/rothkoPkg/rothko.dsc"
