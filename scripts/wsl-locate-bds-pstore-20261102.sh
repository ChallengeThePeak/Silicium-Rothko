#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== BdsMain.c 里 PlatformBootManagerAfterConsole 的位置 ==="
F="$U/Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsMain.c"
rg -n "PlatformBootManagerAfterConsole|PlatformBootManagerBeforeConsole|BootManagerMenu|for \(;;\)" "$F" | head -10

echo
echo "=== 上下文 ==="
rg -n -B8 -A12 "PlatformBootManagerAfterConsole \(BootOption\)" "$F" | head -45

echo
echo "=== FrameBufferSerialPortLib 里 pstore 写入的常量 ==="
rg -n "PSTORE_BASE|PSTORE_PMSG_OFFSET|PSTORE_PMSG_SIZE|PSTORE_SIGNATURE" "$U/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c" | head -8
