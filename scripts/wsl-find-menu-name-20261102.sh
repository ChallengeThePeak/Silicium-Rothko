#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 全树搜 BootManagerMenu FFS 那句 ==="
rg -rn -B14 "BootManagerMenu FFS section" "$U" --glob "*.c" 2>/dev/null | head -34

echo
echo "=== 搜 STI Device Path 那句 ==="
rg -rn -B10 "STI Device Path" "$U" --glob "*.c" 2>/dev/null | head -24

echo
echo "=== PcBdsPkg 在哪 ==="
rg --files "$U" 2>/dev/null | rg "PcBdsPkg" | head -5
