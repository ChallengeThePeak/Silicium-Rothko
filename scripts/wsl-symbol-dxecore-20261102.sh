#!/bin/bash
set -u
B=/home/ubuntu/rothko-upstream-20261102/uefi-full/Build/rothkoPkg/DEBUG_CLANGDWARF
echo "=== DxeCore 产物 ==="
find "$B" -path "*Dxe*" -name "DxeCore.*" 2>/dev/null | head -6
DLL=$(find "$B" -path "*DxeMain*" -name "DxeCore.dll" 2>/dev/null | head -1)
echo "DLL=$DLL"
[ -z "$DLL" ] && exit 1

echo
echo "=== 符号解析 0x1528 / 0x1520 / 0x1530 ==="
for a in 0x1500 0x1528 0x1560; do
  printf "%s -> " "$a"
  llvm-symbolizer --obj="$DLL" "$a" 2>/dev/null | tr '\n' ' ' | head -c 300
  echo
done

echo
echo "=== 反汇编 0x14f0..0x1560 ==="
llvm-objdump -d --no-show-raw-insn --start-address=0x14f0 --stop-address=0x1560 "$DLL" 2>/dev/null | head -50

echo
echo "=== 该函数边界 ==="
llvm-nm --numeric-sort --demangle "$DLL" 2>/dev/null | awk '$1 <= "0000000000001528"' | tail -3
