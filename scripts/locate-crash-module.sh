#!/bin/bash
# Print, for every EFI image, the target of the `bl` at RVA 0x2c34.
#
# The ATF dump shows the CPU alternating between 0x43782C34 (a bl, LR = PC+4)
# and a callee sampled at 0x43781038/0x43781040. With a 4 KiB-aligned image
# base that means base = 0x43780000, caller RVA = 0x2c34 and callee RVA in
# [0x1038, 0x1040]. The owning module therefore has a bl at 0x2c34 whose
# target is at or below 0x1040.
set -uo pipefail

AARCH64=/home/ubuntu/rothko/Mu-Silicium/Build/rothkoPkg/DEBUG_CLANGPDB/AARCH64

printf '%-42s %s\n' "module" "bl 0x2c34 -> target"
printf '%-42s %s\n' "------------------------------------------" "--------------------"

while IFS= read -r efi; do
  line=$(llvm-objdump -d --no-show-raw-insn "$efi" 2>/dev/null | grep -E '^    2c34:' || true)
  case "$line" in
    *bl*)
      target=$(printf '%s\n' "$line" | sed -n 's/.*bl[[:space:]]*\(0x[0-9a-f]*\).*/\1/p')
      printf '%-42s %s\n' "$(basename "$efi")" "${target:-?}"
      ;;
  esac
done < <(find "$AARCH64" -maxdepth 1 -name '*.efi' | sort)
