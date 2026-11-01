#!/bin/bash
# 撤掉主动复位：BDS 末尾只打印标记并停住，等看门狗自然超时（与之前崩溃那几轮同一条路径）
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
BDS="$U/Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsEntry.c"
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$BDS" "$Q/BdsEntry.c.pre-park-$(date +%Y%m%d-%H%M%S)"

python3 - "$BDS" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()

start = s.find('  DEBUG ((DEBUG_ERROR, "K70U-BDS:')
if start < 0:
    print("no K70U-BDS block found"); raise SystemExit

end = s.find("  CpuDeadLoop ();", start)
if end < 0:
    sys.exit("CpuDeadLoop not found")
end += len("  CpuDeadLoop ();")

new = '''  //
  // [k70u-fix 2026-11-02] This platform registers no boot option, so BDS has
  // nothing to boot. Park here instead of resetting: the watchdog that LK armed
  // will expire on its own, which is the same reset path the earlier crashing
  // runs took, and that path keeps DRAM (and therefore the pstore buffer)
  // intact. Do NOT write the watchdog or call ResetSystem here: a PSCI reset
  // behaves like a cold boot on this platform and wipes DRAM.
  //
  DEBUG ((DEBUG_ERROR, "K70U-BDS: no boot option registered, parking for the watchdog\\n"));

  CpuDeadLoop ();'''

s = s[:start] + new + s[end:]
open(p, "w", encoding="utf-8").write(s)
print("BDS set to park")
PY

echo "=== 结果 ==="
rg -n -B2 -A10 "K70U-BDS" "$BDS" | head -20
echo "--- 不应再有 ResetSystem / Rgu ---"
rg -c "ResetSystem \(EfiResetWarm|Rgu\[" "$BDS" || echo "0 (已移除)"
