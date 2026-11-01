#!/bin/bash
# 在 SEC 配置 MMU 后：打印 CurrentEL、SCTLR、并对 0x33FF60000 逐级走页表
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$F" "$Q/MemoryInitPei.c.orig2-$(date +%Y%m%d-%H%M%S)"

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "K70U-PT:" in s:
    print("already patched"); raise SystemExit

anchor = '''  DEBUG ((EFI_D_WARN, "MMU: enabled\\n"));'''
inject = r'''  //
  // [k70u-debug 2026-11-02] Walk the just-installed tables for the address that
  // raised the address size fault, and record the exception level and SCTLR.
  //
  DEBUG ((
    DEBUG_ERROR,
    "K70U-EL: CurrentEL=0x%lx SCTLR=0x%lx TTBR0=0x%lx\\n",
    (UINT64)ArmReadCurrentEL (),
    (UINT64)ArmReadSctlr (),
    (UINT64)ArmGetTTBR0BaseAddress ()
    ));
  {
    UINT64  *Tbl = (UINT64 *)(UINTN)TranslationTableBase;
    UINT64   Va  = 0x33FF60000ULL;
    UINTN    Lvl;

    for (Lvl = 0; Lvl < 4; Lvl++) {
      UINTN   Idx;
      UINT64  Desc;

      if (Tbl == NULL) {
        DEBUG ((DEBUG_ERROR, "K70U-PT: L%u table NULL\\n", (UINT32)Lvl));
        break;
      }

      Idx  = (UINTN)((Va >> (39 - (9 * Lvl))) & 0x1FF);
      Desc = Tbl[Idx];
      DEBUG ((
        DEBUG_ERROR,
        "K70U-PT: VA=0x%lx L%u[%u]=0x%lx\\n",
        Va,
        (UINT32)Lvl,
        (UINT32)Idx,
        Desc
        ));

      if ((Desc & 0x3) == 0x3) {
        break;
      }

      if ((Desc & 0x3) == 0x1) {
        Tbl = (UINT64 *)(UINTN)(Desc & 0x0000FFFFFFFFF000ULL);
      } else {
        DEBUG ((DEBUG_ERROR, "K70U-PT: L%u invalid descriptor\\n", (UINT32)Lvl));
        break;
      }
    }
  }

  DEBUG ((EFI_D_WARN, "MMU: enabled\\n"));'''
if anchor not in s:
    sys.exit("anchor not found")
s = s.replace(anchor, inject, 1)
open(p, "w", encoding="utf-8").write(s)
print("injected")
PY

export PATH=/home/ubuntu/bin:$PATH
rg -n "K70U-EL|K70U-PT" "$F" | head -4
