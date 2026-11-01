#!/bin/bash
# 通用打包：按标签输出 boot/init_boot 并导出到工作区
set -u
LABEL="${1:?label required}"
BASE=/home/ubuntu/rothko-upstream-20261102
PORT="$BASE/Silicium-Rothko"
UEFI="$BASE/uefi-full"
IMAGES="/mnt/c/Users/Administrator/Downloads/rothko_images_OS1.0.22.0.UNNCNXM_20240808.0000.00_14.0_cn_197c33cf17/rothko_images_OS1.0.22.0.UNNCNXM_14.0/images"
FD="$UEFI/Build/rothkoPkg/DEBUG_CLANGDWARF/FV/SILICIUM_UEFI.fd"
OUT="$BASE/rothko-$LABEL"
DST="/mnt/d/漏洞/UNIXNU/适配K70U/bringup"
mkdir -p "$OUT"

echo "=== FD ==="; sha256sum "$FD"; ls -l "$FD"
FAT="$BASE/rothko-pstore-uefi-20261102/init_boot_fat.img"

cd "$PORT/tools" || exit 1
python3 boot_v4.py \
  --boot-template "$IMAGES/boot.img" \
  --init-boot-template "$IMAGES/init_boot.img" \
  --vendor-boot "$IMAGES/vendor_boot.img" \
  --uefi "$UEFI" --fd "$FD" \
  --fd-base 0x40400000 --fd-size 0x200000 \
  --kernel-compression lz4 --preserve-avb-tail \
  --fat-image "$FAT" \
  --boot-output "$OUT/boot-$LABEL.img" \
  --init-boot-output "$OUT/init_boot-$LABEL.img" \
  --report "$OUT/packing-report.json" 2>&1 | grep -E "kernel_bytes|decoded_kernel|avb_tail_preserved|shim_bytes|image_text_offset" | head -6

echo "=== 导出 ==="
cp -f "$OUT/boot-$LABEL.img" "$DST/boot-k70u-uefi-$LABEL.img"
cp -f "$OUT/init_boot-$LABEL.img" "$DST/init_boot-k70u-uefi-$LABEL.img"
cp -f "$FD" "$DST/SILICIUM_UEFI-$LABEL.fd"
ls -l "$DST"/*"$LABEL"*
sha256sum "$DST"/*"$LABEL"*
