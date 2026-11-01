#!/bin/bash
set -u
C=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== build_uefi.py 关键点 ==="
grep -nE "rothko|CLANGDWARF|CLANGPDB|FD_BASE|subprocess|def build|DeviceBuild|stuart" "$C/build_uefi.py" | head -30
echo
echo "=== Configs 目录 ==="
ls "$C/Resources/Configs" 2>/dev/null | head -20
echo
echo "=== 是否有 rothko 配置 ==="
grep -rl "rothko" "$C/Resources" 2>/dev/null | head -10
echo
echo "=== rothkoPkg 里的 README 构建说明 ==="
sed -n '1,40p' "$C/Platforms/Xiaomi/rothkoPkg/README.md" 2>/dev/null
