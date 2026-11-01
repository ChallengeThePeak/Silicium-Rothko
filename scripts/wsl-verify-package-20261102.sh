#!/bin/bash
# 校验产物：pstore 标记存在、AVB 尾一致、解压后 FD 字节一致，并导出到 Windows 工作区
set -u
BASE=/home/ubuntu/rothko-upstream-20261102
OUT="$BASE/rothko-pstore-uefi-20261102"
FD="$BASE/uefi-full/Build/rothkoPkg/DEBUG_CLANGDWARF/FV/SILICIUM_UEFI.fd"
DST="/mnt/d/漏洞/UNIXNU/适配K70U/bringup"

echo "=== 1) FD 内关键标记 ==="
for s in K70U_UEFI_PSTORE_BEGIN "SEC: loading DXE core" "Loading DxeCore" FrameBufferSerialPort; do
  n=$(grep -c -a "$s" "$FD" 2>/dev/null || true)
  printf "%-32s %s\n" "$s" "$([ "${n:-0}" -gt 0 ] && echo 命中 || echo 未命中)"
done
echo "FD: $(stat -c %s "$FD") bytes  sha256=$(sha256sum "$FD" | cut -d' ' -f1)"

echo
echo "=== 2) boot 镜像：解压 kernel -> shim+FD 一致性 ==="
cd "$BASE/Silicium-Rothko/tools" || exit 1
python3 - "$OUT/boot-uefi-pstore.img" "$FD" <<'PY'
import sys, hashlib
sys.path.insert(0, ".")
import boot_v4
img = open(sys.argv[1], "rb").read()
ks = boot_v4.u32(img, 8)
kernel = img[4096:4096 + ks]
decoded, comp = boot_v4.decompress_kernel(kernel)
fd = open(sys.argv[2], "rb").read()
print("compression:", comp, "decoded:", len(decoded))
print("shim bytes:", len(decoded) - len(fd))
print("FD 尾段与编译产物一致:", decoded[-len(fd):] == fd)
print("Image 头 text_offset:", boot_v4.u32(decoded, 8), "flags:", hex(boot_v4.u32(decoded, 24)))
print("shim 里写的 FD_BASE 字面量是否存在:", b"\x00\x00\x40\x40\x00\x00\x00\x00" in decoded[:256])
PY

echo
echo "=== 3) AVB 尾部是否与模板逐字节一致 ==="
python3 - "$OUT/boot-uefi-pstore.img" "/mnt/c/Users/Administrator/Downloads/rothko_images_OS1.0.22.0.UNNCNXM_20240808.0000.00_14.0_cn_197c33cf17/rothko_images_OS1.0.22.0.UNNCNXM_14.0/images/boot.img" <<'PY'
import sys
sys.path.insert(0, "/home/ubuntu/rothko-upstream-20261102/Silicium-Rothko/tools")
import boot_v4
img = open(sys.argv[1], "rb").read()
tpl = open(sys.argv[2], "rb").read()
tail = boot_v4.avb_tail_offset(tpl, "tpl")
print("tail offset:", hex(tail), "尾部一致:", img[tail:] == tpl[tail:])
print("末尾 AVBf:", img[-64:-60])
PY

echo
echo "=== 4) 导出到工作区 ==="
cp -f "$OUT/boot-uefi-pstore.img" "$DST/boot-k70u-uefi-pstore-20261102.img"
cp -f "$OUT/init_boot-uefi-pstore.img" "$DST/init_boot-k70u-uefi-pstore-20261102.img"
cp -f "$OUT/packing-report.json" "$DST/boot-k70u-uefi-pstore-20261102.report.json"
cp -f "$FD" "$DST/SILICIUM_UEFI-pstore-20261102.fd"
ls -l "$DST"/*pstore-20261102*
sha256sum "$DST"/*pstore-20261102*
