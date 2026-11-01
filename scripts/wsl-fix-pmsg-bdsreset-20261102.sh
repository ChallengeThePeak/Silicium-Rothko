#!/bin/bash
# 1) pmsg 写入基址改为内核认的 0x480D1000（同时保留旧位置）
# 2) BDS 结束后主动热复位，让设备自己回到 bootloader 且 DRAM 保留
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
LIB="$U/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c"
BDS="$U/Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsEntry.c"
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$LIB" "$Q/FrameBufferSerialPortLib.c.pre-pmsgfix-$(date +%Y%m%d-%H%M%S)"
cp -f "$BDS" "$Q/BdsEntry.c.orig-$(date +%Y%m%d-%H%M%S)"

python3 - "$LIB" "$BDS" <<'PY'
import sys
lib, bds = sys.argv[1], sys.argv[2]

# ---------- 1) pstore 基址 ----------
s = open(lib, encoding="utf-8").read()
if "PSTORE_PMSG_BASE_KERNEL" not in s:
    s = s.replace(
        "#define PSTORE_SIGNATURE  0x43474244",
        "#define PSTORE_SIGNATURE  0x43474244\n"
        "//\n"
        "// [k70u-fix 2026-11-02] The kernel owns this region as ramoops:\n"
        "//   ramoops.mem_address=0x48090000 mem_size=0xe0000\n"
        "//   console_size=0x40000 pmsg_size=0x80000, record_size defaults to 0x1000\n"
        "// so the kernel expects the pmsg buffer to start at 0x480D1000. Upstream wrote\n"
        "// at base+0x60000 (0x480F0000), i.e. 0x1F000 bytes into the pmsg area, so the\n"
        "// kernel never recognised the buffer and pmsg-ramoops-0 was never created.\n"
        "// Write to the kernel's expected start, and keep the legacy offset as a mirror.\n"
        "#define PSTORE_PMSG_BASE_KERNEL 0x480D1000\n"
        "#define PSTORE_PMSG_BASE_LEGACY  (PSTORE_BASE + PSTORE_PMSG_OFFSET)",
        1,
    )

    s = s.replace(
        "PstoreWrite (\n  IN CONST UINT8  *Data,\n  IN UINTN         Length\n  )\n{\n  PSTORE_BUFFER  *Buffer;",
        "PstoreWriteAt (\n  IN CONST UINT8  *Data,\n  IN UINTN         Length,\n  IN UINTN         Base\n  )\n{\n  PSTORE_BUFFER  *Buffer;",
        1,
    )
    s = s.replace(
        "  Buffer   = (PSTORE_BUFFER *)(UINTN)(PSTORE_BASE + PSTORE_PMSG_OFFSET);",
        "  Buffer   = (PSTORE_BUFFER *)(UINTN)Base;",
        1,
    )
    s = s.replace(
        "  MemoryFence ();\n}\n\nVOID\nEFIAPI\nPstoreLogBegin (",
        "  MemoryFence ();\n}\n\nSTATIC\nVOID\nPstoreWrite (\n  IN CONST UINT8  *Data,\n  IN UINTN         Length\n  )\n{\n  PstoreWriteAt (Data, Length, PSTORE_PMSG_BASE_KERNEL);\n  PstoreWriteAt (Data, Length, PSTORE_PMSG_BASE_LEGACY);\n}\n\nVOID\nEFIAPI\nPstoreLogBegin (",
        1,
    )
    open(lib, "w", encoding="utf-8").write(s)
    print("pstore base patched")
else:
    print("pstore base already patched")

# ---------- 2) BDS 结束后热复位 ----------
t = open(bds, encoding="utf-8").read()
if "K70U-BDS" not in t:
    anchor = '  PlatformBootManagerAfterConsole ();\n  PERF_INMODULE_END ("PlatformBootManagerAfterConsole");'
    add = anchor + """

  //
  // [k70u-fix 2026-11-02] This platform registers no boot option yet, so BDS
  // would idle forever and the device would never come back on its own. Warm
  // reset after a short delay: the device returns to the bootloader by itself
  // and, because a warm reset keeps DRAM, the pstore buffer written by SEC/DXE
  // is still there for the next reader.
  //
  DEBUG ((DEBUG_ERROR, "K70U-BDS: no boot option registered, warm reset in 15s\\n"));
  gBS->Stall (15 * 1000000);
  gRT->ResetSystem (EfiResetWarm, EFI_SUCCESS, 0, NULL);"""
    if anchor not in t:
        sys.exit("BDS anchor missing")
    t = t.replace(anchor, add, 1)
    open(bds, "w", encoding="utf-8").write(t)
    print("BDS warm reset patched")
else:
    print("BDS already patched")
PY

echo "=== 校验 ==="
rg -n "PSTORE_PMSG_BASE_KERNEL|PstoreWriteAt" "$LIB" | head -6
rg -n -A3 "K70U-BDS" "$BDS" | head -8
