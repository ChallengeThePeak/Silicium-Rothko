#!/bin/bash
# 上游打包脚本结构与 BootShim 源位置
set -u
PORT=/home/ubuntu/rothko-upstream-20261102/Silicium-Rothko
UP=/home/ubuntu/rothko-upstream-20261102/uefi-src

echo "=== boot_v4.py 规模与函数表 ==="
wc -l "$PORT/tools/boot_v4.py"
grep -nE "^def |^class |^V4_|^[A-Z_]+ = " "$PORT/tools/boot_v4.py" | head -50
echo
echo "=== boot_v4.py 关键常量/默认值 ==="
grep -nE "0x40400000|FD_BASE|text_offset|flags|preserve.?avb|LZ4|lz4|AVBf|0x1000" "$PORT/tools/boot_v4.py" | head -40

echo
echo "=== uefi-src 中 BootShim 相关文件 ==="
cd "$UP" || exit 1
git ls-tree -r HEAD --name-only | grep -iE "bootshim|shim" | head -20
