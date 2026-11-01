#!/bin/bash
set -u
DLL=/home/ubuntu/rothko-upstream-20261102/uefi-full/Build/rothkoPkg/DEBUG_CLANGDWARF/AARCH64/MdeModulePkg/Core/Dxe/DxeMain/DEBUG/DxeCore.dll
echo "=== 本版 DxeCore 基址 0x40E5C000 相关 RVA 符号化 ==="
for off in 0x3E0C 0x1C93C 0x28344 0x1DBB8 0x2BB2C; do
  printf "%-8s -> " "$off"
  llvm-symbolizer --obj="$DLL" "$off" 2>/dev/null | tr '\n' ' ' | head -c 220
  echo
done

echo
echo "=== 0x3E0C 附近反汇编 ==="
llvm-objdump -d --no-show-raw-insn --start-address=0x3DE0 --stop-address=0x3E30 "$DLL" 2>/dev/null | tail -20

echo
echo "=== 该 RVA 落在哪个函数（nm）==="
llvm-nm --numeric-sort "$DLL" 2>/dev/null | awk '$1 <= "0000000000003e0c"' | tail -3
