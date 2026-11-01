#!/bin/bash
# 校验：本次模板与历史候选镜像是否同源；并把产物拷到 Windows 工作区
set -u
OUT=/home/ubuntu/rothko-pstore-probe-20261102
TPL="/mnt/c/Users/Administrator/Downloads/rothko_images_OS1.0.22.0.UNNCNXM_20240808.0000.00_14.0_cn_197c33cf17/rothko_images_OS1.0.22.0.UNNCNXM_14.0/images/boot.img"
DST="/mnt/d/漏洞/UNIXNU/适配K70U/bringup"

python3 - "$TPL" <<'PY'
import sys, struct, glob, os
tpl = open(sys.argv[1], "rb").read()
hdr = tpl[:4096]
print("模板 boot.img: size", len(tpl), "kernel", hex(struct.unpack_from('<I', hdr, 8)[0]))
for path in sorted(glob.glob("/mnt/d/漏洞/UNIXNU/适配K70U/bringup/boot-rothko-*.img"))[-4:]:
    with open(path, "rb") as f:
        h = f.read(4096)
    diff = [i for i in range(4096) if h[i] != hdr[i]]
    # 只允许 header 内 kernel_size(8..12)/ramdisk_size(12..16) 等尺寸字段不同
    diff_outside_sizes = [i for i in diff if not (8 <= i < 16)]
    print(os.path.basename(path),
          "| 不同字节数", len(diff),
          "| 尺寸字段外不同", len(diff_outside_sizes),
          "| kernel_size", hex(struct.unpack_from('<I', h, 8)[0]),
          "| header_version", struct.unpack_from('<I', h, 40)[0])
PY

echo "=== 拷产物到工作区 ==="
cp -f "$OUT/boot-k70u-pstore-probe-20s.img" "$DST/boot-k70u-pstore-probe-20s-20261102.img"
cp -f "$OUT/probe-report.json" "$DST/boot-k70u-pstore-probe-20s-20261102.report.json"
cp -f "$OUT/pstore-20s-assembly.txt" "$DST/boot-k70u-pstore-probe-20s-20261102.asm.txt"
ls -l "$DST"/boot-k70u-pstore-probe-20s-20261102.*
sha256sum "$DST/boot-k70u-pstore-probe-20s-20261102.img"
