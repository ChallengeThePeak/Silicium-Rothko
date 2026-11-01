#!/bin/bash
set -u
F=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c
echo "=== 行数 ==="; wc -l "$F"
echo "=== 关键常量与描述符构建 ==="
grep -nE "0x[0-9A-Fa-f]{6,}|ResourceType|ResourceAttribute|BuildResourceDescriptor|TESTED|PRESENT|Length|Reserved" "$F" | head -60
