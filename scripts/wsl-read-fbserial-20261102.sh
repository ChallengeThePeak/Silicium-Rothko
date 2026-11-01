#!/bin/bash
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
F=$(find "$U/Silicon/Silicium" -path "*FrameBufferSerialPortLib*" -name "*.c" | head -1)
echo "FILE=$F"
echo "=== 是否/如何启用 framebuffer ==="
grep -nE "Framebuffer|FrameBuffer|Pcd|return|if \(|BaseAddress|Size" "$F" | head -40
echo
echo "=== 头部 include 与全局 ==="
sed -n '1,60p' "$F"
