#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
D=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c

echo "=== Refresh 开头与 mDirty ==="
rg -n -B4 -A16 "if \(!mRefreshActive \|\| !mDirty\)" "$D" | head -30

echo
echo "=== 定时器怎么建的（mRefreshEvent / TimerPeriod）==="
rg -n "mRefreshEvent|CreateEvent|CreateTimer|SetTimer|WaitForEvent|RegisterProtocolNotify" "$D" | head -20

echo
echo "=== mDirty 的所有赋值点 ==="
rg -n "mDirty" "$D" | head -12
