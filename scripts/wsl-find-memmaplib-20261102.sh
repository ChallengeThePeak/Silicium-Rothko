#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
echo "=== 所有 MemoryMapLib ==="
find "$U" -name "MemoryMapLib*" -not -path "*/.git/*" | head -10
echo
echo "=== 谁调用 BuildResourceDescriptorHob（含 SYSTEM_MEMORY）==="
grep -rln "BuildResourceDescriptorHob" "$U" --include="*.c" 2>/dev/null | grep -iv basecore | head -10
echo
echo "=== rothko 表结构定义（含 BootShim Source 字符串的文件）==="
grep -rln "BootShim Source" "$U" --include="*.c" --include="*.h" 2>/dev/null | head -5
