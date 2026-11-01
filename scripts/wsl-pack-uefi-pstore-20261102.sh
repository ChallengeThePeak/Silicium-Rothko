#!/bin/bash
# 按上游文档打包 boot/init_boot（保留 AVB 尾部、legacy LZ4、1 MiB FAT）
set -u
BASE=/home/ubuntu/rothko-upstream-20261102
PORT="$BASE/Silicium-Rothko"
UEFI="$BASE/uefi-full"
IMAGES="/mnt/c/Users/Administrator/Downloads/rothko_images_OS1.0.22.0.UNNCNXM_20240808.0000.00_14.0_cn_197c33cf17/rothko_images_OS1.0.22.0.UNNCNXM_14.0/images"
OUT="$BASE/rothko-pstore-uefi-20261102"
FD="$UEFI/Build/rothkoPkg/DEBUG_CLANGDWARF/FV/SILICIUM_UEFI.fd"

mkdir -p "$OUT"

echo "=== UniXNU 只读软链（boot_v4.py 需要 scripts）==="
if [ ! -e "$BASE/UniXNU" ]; then ln -s /home/ubuntu/UniXNU "$BASE/UniXNU"; echo "已建"; else echo "已存在: $(readlink -f "$BASE/UniXNU")"; fi
ls -d "$BASE/UniXNU/scripts" 2>&1 | tail -1

echo "=== FD 检查 ==="
ls -l "$FD" || { echo "没有 FD，先编译"; exit 3; }
python3 - "$FD" <<'PY'
import sys
d = open(sys.argv[1], "rb").read()
print("FD bytes", len(d), hex(len(d)), "magic", d[40:44])
PY

echo "=== 1 MiB FAT12 ==="
FAT="$OUT/init_boot_fat.img"
if [ ! -f "$FAT" ]; then mkfs.fat -C -F 12 "$FAT" 1024 >/dev/null; fi
ls -l "$FAT"; python3 -c "import sys;d=open(sys.argv[1],'rb').read();print('fat bytes',len(d),'sig',d[510:512].hex())" "$FAT"

echo "=== vendor ramdisk 偏移（PCD 应等于此值）==="
cd "$PORT/tools" && python3 - "$PORT" "$IMAGES/vendor_boot.img" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]) / "tools"))
from boot_v4 import normal_vendor_ramdisk_size
size = normal_vendor_ramdisk_size(Path(sys.argv[2]).read_bytes())
print(f"PcdUniXNURamDiskOffset|{size:#x} ({size} bytes)")
PY

echo "=== 打包 ==="
cd "$PORT/tools" || exit 1
python3 boot_v4.py \
  --boot-template "$IMAGES/boot.img" \
  --init-boot-template "$IMAGES/init_boot.img" \
  --vendor-boot "$IMAGES/vendor_boot.img" \
  --uefi "$UEFI" \
  --fd "$FD" \
  --fd-base 0x40400000 --fd-size 0x200000 \
  --kernel-compression lz4 --preserve-avb-tail \
  --fat-image "$FAT" \
  --boot-output "$OUT/boot-uefi-pstore.img" \
  --init-boot-output "$OUT/init_boot-uefi-pstore.img" \
  --report "$OUT/packing-report.json" 2>&1 | tail -40

echo "=== 产物 ==="
ls -l "$OUT"/*.img
sha256sum "$OUT"/*.img
