#!/bin/bash
# 在 Gcd.c 断言前插入 HOB 实表转储，供下一轮实机定位
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Mu_Basecore/MdeModulePkg/Core/Dxe/Gcd/Gcd.c
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$F" "$Q/Gcd.c.orig-$(date +%Y%m%d-%H%M%S)"

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="surrogateescape").read()
anchor = "  //\n  // Assert if a resource descriptor HOB for the memory region described by the PHIT was not found\n  //\n  ASSERT (Found);"
if anchor not in s:
    sys.exit("anchor not found")
inject = r'''  //
  // [k70u-debug 2026-11-02] Dump the PHIT range and every resource descriptor HOB
  // so the Gcd.c(2420) assertion can be localised from pstore alone.
  //
  DEBUG ((
    DEBUG_ERROR,
    "K70U-GCD: PhitFreeBottom=0x%lx PhitFreeTop=0x%lx PhitMemTop=0x%lx Found=%d\n",
    (UINT64)PhitHob->EfiFreeMemoryBottom,
    (UINT64)PhitHob->EfiFreeMemoryTop,
    (UINT64)PhitHob->EfiMemoryTop,
    Found
    ));
  for (Hob.Raw = *HobStart; !END_OF_HOB_LIST (Hob); Hob.Raw = GET_NEXT_HOB (Hob)) {
    if ((GET_HOB_TYPE (Hob) != EFI_HOB_TYPE_RESOURCE_DESCRIPTOR) &&
        (GET_HOB_TYPE (Hob) != EFI_HOB_TYPE_RESOURCE_DESCRIPTOR2)) {
      continue;
    }

    DEBUG ((
      DEBUG_ERROR,
      "K70U-GCD: RD base=0x%lx len=0x%lx type=0x%x attr=0x%x\n",
      Hob.ResourceDescriptor->PhysicalStart,
      Hob.ResourceDescriptor->ResourceLength,
      Hob.ResourceDescriptor->ResourceType,
      Hob.ResourceDescriptor->ResourceAttribute
      ));
  }

'''
s = s.replace(anchor, inject + anchor, 1)
open(p, "w", encoding="utf-8", errors="surrogateescape").write(s)
print("injected")
PY

echo "=== 注入结果确认 ==="
grep -n "K70U-GCD" "$F" | head -5
