#!/bin/bash
# 1) 内存表加入 MTK WDT 寄存器区（否则写 WDT 会 data abort）
# 2) BDS 结束改用 WDT 超时复位（替代 PSCI 热复位：PSCI 在 MTK 上等价冷复位，DRAM 会被清）
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
MAP="$U/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c"
BDS="$U/Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsEntry.c"
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$MAP" "$Q/MemoryMapLib.c.pre-wdt-$(date +%Y%m%d-%H%M%S)"
cp -f "$BDS" "$Q/BdsEntry.c.pre-wdt-$(date +%Y%m%d-%H%M%S)"

python3 - "$MAP" "$BDS" <<'PY'
import sys
mapf, bdsf = sys.argv[1], sys.argv[2]

# ---------- 1) WDT 寄存器区 ----------
s = open(mapf, encoding="utf-8").read()
if '"Watchdog"' not in s:
    anchor = '  {"GIC Distributor",   0x0C400000, 0x00040000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},'
    if anchor not in s:
        sys.exit("map anchor missing")
    add = anchor + """
  //
  // [k70u-fix 2026-11-02] MTK watchdog registers, used to force a watchdog
  // reset (a PSCI SYSTEM_RESET behaves like a cold boot here and wipes DRAM,
  // which loses the pstore buffer). WDT_LENGTH is at +4, WDT_RESTART at +8.
  //
  {"Watchdog",        0x1C00B000, 0x00001000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},"""
    s = s.replace(anchor, add, 1)
    open(mapf, "w", encoding="utf-8").write(s)
    print("watchdog region added")
else:
    print("watchdog region already present")

# ---------- 2) BDS 用 WDT 复位 ----------
t = open(bdsf, encoding="utf-8").read()
old = """  DEBUG ((DEBUG_ERROR, "K70U-BDS: no boot option registered, warm reset in 15s\\n"));
  gBS->Stall (15 * 1000000);
  gRT->ResetSystem (EfiResetWarm, EFI_SUCCESS, 0, NULL);"""
new = """  DEBUG ((DEBUG_ERROR, "K70U-BDS: no boot option registered, arming watchdog reset\\n"));
  {
    //
    // MTK watchdog: WDT_LENGTH at +4 encodes the timeout as (seconds << 11) | 8,
    // WDT_RESTART at +8 kicks the counter. Arm a short timeout, kick it once and
    // then stop servicing it, so the SoC is reset by the watchdog. That path
    // keeps DRAM alive, which a PSCI SYSTEM_RESET does not on this platform.
    //
    volatile UINT32 *Rgu = (volatile UINT32 *)(UINTN)0x1C00B000;

    Rgu[1] = (7U << 11) | 8U;
    __asm__ volatile ("dsb sy" ::: "memory");
    Rgu[2] = 0x1971U;
    __asm__ volatile ("dsb sy" ::: "memory");
  }

  CpuDeadLoop ();"""
if old in t:
    t = t.replace(old, new, 1)
    open(bdsf, "w", encoding="utf-8").write(t)
    print("BDS switched to watchdog reset")
elif "K70U-BDS" in t:
    print("BDS already patched, left as is")
else:
    sys.exit("BDS anchor missing")
PY

echo "=== 校验 ==="
rg -n "Watchdog" "$MAP" | head -3
rg -n -A6 "K70U-BDS" "$BDS" | head -12
