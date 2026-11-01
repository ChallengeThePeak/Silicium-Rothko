#!/bin/bash
set -u
DLL=/home/ubuntu/rothko-upstream-20261102/uefi-full/Build/rothkoPkg/DEBUG_CLANGDWARF/AARCH64/MdeModulePkg/Core/Dxe/DxeMain/DEBUG/DxeCore.dll
echo "=== 崩溃栈符号化（相对 DxeCore 基址 0x40E56000）==="
for off in 0xF464 0xF19C 0xF750 0x851C 0x1D158 0x1DA64 0x1DC94 0x1F0CC 0x6580 0x2B24 0x2814; do
  printf "%s -> " "$off"
  llvm-symbolizer --obj="$DLL" "$off" 2>/dev/null | tr '\n' ' ' | head -c 200
  echo
done

echo
echo "=== 反汇编 0xF430..0xF490（故障指令）==="
llvm-objdump -d --no-show-raw-insn --start-address=0xF430 --stop-address=0xF490 "$DLL" 2>/dev/null | tail -25
