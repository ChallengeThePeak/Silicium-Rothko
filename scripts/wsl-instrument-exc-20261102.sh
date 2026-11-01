#!/bin/bash
# 在异常处理打印寄存器前，补打 EL/TCR/TTBR0/SCTLR，定位异常时刻的翻译制式
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore/UefiCpuPkg/Library/CpuExceptionHandlerLib/AArch64/CpuExceptionHandlerLib.c
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$F" "$Q/CpuExceptionHandlerLib.c.orig-$(date +%Y%m%d-%H%M%S)"
export PATH=/home/ubuntu/bin:$PATH

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "K70U-EXC" in s:
    print("already patched"); raise SystemExit

anchor = '  DescribeExceptionSyndrome (SystemContext.SystemContextAArch64->ESR);'
inject = r'''  //
  // [k70u-debug 2026-11-02] Record the translation regime in force when the
  // fault was taken. The SEC-time values are known; these must match them.
  //
  {
    UINT64  Tcr;
    UINT64  Ttbr0;
    UINT64  Sctlr;
    UINT64  El;

    __asm__ __volatile__ ("mrs %0, tcr_el1"   : "=r" (Tcr));
    __asm__ __volatile__ ("mrs %0, ttbr0_el1" : "=r" (Ttbr0));
    __asm__ __volatile__ ("mrs %0, sctlr_el1" : "=r" (Sctlr));
    __asm__ __volatile__ ("mrs %0, CurrentEL" : "=r" (El));

    DEBUG ((
      DEBUG_ERROR,
      "K70U-EXC: CurrentEL=0x%lx SCTLR=0x%lx TCR=0x%lx TTBR0=0x%lx T0SZ=0x%lx\n",
      El,
      Sctlr,
      Tcr,
      Ttbr0,
      Tcr & 0x3F
      ));
  }

  DescribeExceptionSyndrome (SystemContext.SystemContextAArch64->ESR);'''
if anchor not in s:
    sys.exit("anchor not found")
s = s.replace(anchor, inject, 1)
open(p, "w", encoding="utf-8").write(s)
print("injected")
PY

rg -n "K70U-EXC" "$F" | head -3
