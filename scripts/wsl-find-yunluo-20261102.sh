#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 树里有没有 yunluo ==="
rg -rl -i "yunluo" "$U" 2>/dev/null | head -10
ls -d "$U/Platforms"/*/ 2>/dev/null | head -30

echo
echo "=== 所有平台的显示驱动 ==="
rg --files "$U/Platforms" 2>/dev/null | rg -i "display|framebuffer|fb|gop" | head -25

echo
echo "=== 哪些平台的 DSC 用了 1220x2712 ==="
rg -rn "2712" "$U/Platforms" 2>/dev/null | head -12
