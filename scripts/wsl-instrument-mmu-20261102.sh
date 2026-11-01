#!/bin/bash
# 在 SEC 配置 MMU 之后打印地址宽度/寄存器，用于定位 address size fault
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$F" "$Q/MemoryInitPei.c.orig-$(date +%Y%m%d-%H%M%S)"
export PATH=/home/ubuntu/bin:$PATH

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "K70U-MMU" in s:
    print("already patched"); raise SystemExit

anchor = '''  DEBUG ((EFI_D_WARN, "MMU: enabled\\n"));'''
inject = '''  //
  // [k70u-debug 2026-11-02] Record the translation regime actually programmed:
  // the DXE pool allocator handed out 0x33FF60000 and the store raised an
  // address size fault, which means the VA range does not reach that far.
  //
  DEBUG ((
    DEBUG_ERROR,
    "K70U-MMU: PAbits=%d T0SZ=0x%x TTBR0=0x%lx TCR=0x%lx regions=%d\\n",
    (UINT32)ArmGetPhysicalAddressBits (),
    (UINT32)(ArmGetTCR () & 0x3F),
    (UINT64)ArmGetTTBR0BaseAddress (),
    (UINT64)ArmGetTCR (),
    (UINT32)MemoryDescriptorCount
    ));
  DEBUG ((EFI_D_WARN, "MMU: enabled\\n"));'''
if anchor not in s:
    sys.exit("anchor not found")
s = s.replace(anchor, inject, 1)
open(p, "w", encoding="utf-8").write(s)
print("injected")
PY

rg -n "K70U-MMU" "$F" | head -3
echo "=== 是否已包含 ArmLib.h ==="
rg -n "ArmLib.h" "$F" || echo "需要补 include"
