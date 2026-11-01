#!/bin/bash
# 驱动改为持续推帧（不再只在 GOP blt 时推），并把节拍调到 200 ms
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c
Q=/home/ubuntu/quarantine
cp -f "$D" "$Q/RothkoDisplayDxe.c.pre-push-$(date +%Y%m%d-%H%M%S)"

python3 - "$D" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()

old = """  if (!mRefreshActive || !mDirty) {
    return;
  }"""
new = """  if (!mRefreshActive) {
    return;
  }

  //
  // [k70u-fix 2026-11-02] Submit on every tick, not only after a GOP blt.
  // The frame buffer console in FrameBufferSerialPortLib draws the UEFI log
  // straight into the frame buffer, and those writes never go through the
  // GOP, so a dirty-only refresh keeps showing the last pushed frame and the
  // log never reaches the panel. The yunluo reference behaves the same way:
  // the panel keeps being refreshed while the log is written, which is why
  // its early boot shows the text appearing line by line.
  //"""
if old in s:
    s = s.replace(old, new, 1); print("dirty gate removed")
else:
    print("dirty gate pattern not found")

old_t = "Status = gBS->SetTimer (mRefreshEvent, TimerPeriodic, 1000000ULL);"
new_t = ("// [k70u-fix 2026-11-02] 200 ms: fast enough for the log to appear to\n"
         "  // scroll, slow enough not to spend the whole boot copying the frame.\n"
         "  Status = gBS->SetTimer (mRefreshEvent, TimerPeriodic, 200000ULL);")
if old_t in s:
    s = s.replace(old_t, new_t, 1); print("timer period 200 ms")
else:
    print("timer pattern not found")

open(p, "w", encoding="utf-8").write(s)
PY

echo
echo "=== 校验 ==="
rg -n -A4 "if \(!mRefreshActive\)" "$D" | head -8
rg -n "SetTimer \(mRefreshEvent" "$D" | head -3
