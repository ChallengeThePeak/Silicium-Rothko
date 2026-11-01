#!/bin/bash
# 打包 GCD 调试版 boot，输出到独立文件名，导出到工作区
set -u
BASE=/home/ubuntu/rothko-upstream-20261102
PORT="$BASE/Silicium-Rothko"
UEFI="$BASE/uefi-full"
IMAGES="/mnt/c/Users/Administrator/Downloads/rothko_images_OS1.0.22.0.UNNCNXM_20240808.0000.00_14.0_cn_197c33cf17/rothko_images_OS1.0.22.0.UNNCNXM_14.0/images"
OUT="$BASE/rothko-pstore-gcddbg-20261102"
FD="$UEFI/Build/rothkoPkg/DEBUG_CLANGDWARF/FV/SILICIUM_UEFI.fd"
DST="/mnt/d/漏洞/UNIXNU/适配K70U/bringup"
mkdir -p "$OUT"

echo "=== FD ==="
ls -l "$FD"; sha256sum "$FD"

echo "=== 确认调试字符串在 FD 里 ==="
grep -c -a "K70U-GCD" "$FD" || true

FAT="$BASE/rothko-pstore-uefi-20261102/init_boot_fat.img"
ls -l "$FAT"

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
  --boot-output "$OUT/boot-uefi-pstore-gcddbg.img" \
  --init-boot-output "$OUT/init_boot-uefi-pstore-gcddbg.img" \
  --report "$OUT/packing-report.json" 2>&1 | tail -25

echo "=== 导出 ==="
cp -f "$OUT/boot-uefi-pstore-gcddbg.img" "$DST/boot-k70u-uefi-pstore-gcddbg-20261102.img"
cp -f "$FD" "$DST/SILICIUM_UEFI-pstore-gcddbg-20261102.fd"
ls -l "$DST"/*gcddbg*
sha256sum "$DST"/*gcddbg*
