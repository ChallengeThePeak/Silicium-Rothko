#!/bin/bash
# 按上游原样构建 pstore 写标记探针（PROBE_PSTORE=1, 20s 后 PSCI 复位）
# 只替换 boot 的 kernel 字段，stock AVB 尾部原样保留；不动 init_boot。
set -eu

UP=/home/ubuntu/rothko-upstream-20261102/uefi-src
PORT=/home/ubuntu/rothko-upstream-20261102/Silicium-Rothko
OUT=/home/ubuntu/rothko-pstore-probe-20261102
TPL="/mnt/c/Users/Administrator/Downloads/rothko_images_OS1.0.22.0.UNNCNXM_20240808.0000.00_14.0_cn_197c33cf17/rothko_images_OS1.0.22.0.UNNCNXM_14.0/images/boot.img"

mkdir -p "$OUT"
echo "=== 1) 取探针源码 ==="
cd "$UP"
git show HEAD:BootShim/BootShimEntryProbe.S > "$OUT/BootShimEntryProbe.S"
ls -l "$OUT/BootShimEntryProbe.S"

echo "=== 2) 编译 pstore 变体 ==="
clang --target=aarch64-none-elf -c "$OUT/BootShimEntryProbe.S" \
  -DPROBE_DELAY_S=20 -DPROBE_DIRECT_RESET=0 -DPROBE_PSTORE=1 \
  -o "$OUT/pstore-20s.o"
llvm-objcopy -O binary "$OUT/pstore-20s.o" "$OUT/pstore-20s.bin"
ls -l "$OUT/pstore-20s.bin"

echo "=== 3) 反汇编校验（入口 0x40..0x140）==="
llvm-objdump -d --no-show-raw-insn --start-address=0x40 --stop-address=0x140 "$OUT/pstore-20s.o" \
  | tee "$OUT/pstore-20s-assembly.txt" | head -30

echo "=== 4) 打包（保留 AVB 尾部 + legacy LZ4）==="
cd "$PORT/tools"
python3 - "$TPL" "$OUT" <<'PY'
import sys, os, json, struct
sys.path.insert(0, os.getcwd())
import boot_v4

tpl_path, out = sys.argv[1], sys.argv[2]
tpl = open(tpl_path, "rb").read()
print("template bytes", len(tpl), "magic", tpl[:8],
      "hdr_ver", struct.unpack_from("<I", tpl, 40)[0],
      "kernel_size", hex(struct.unpack_from("<I", tpl, 8)[0]),
      "ramdisk", hex(struct.unpack_from("<I", tpl, 12)[0]),
      "sig_size", struct.unpack_from("<I", tpl, 1580)[0])
print("footer magic", tpl[-64:-60])

raw = open(os.path.join(out, "pstore-20s.bin"), "rb").read()
text_offset, image_size, flags = struct.unpack_from("<QQQ", raw, 8)
assert raw[56:60] == b"ARM\x64", "missing ARM64 Image magic"
assert text_offset == 0 and image_size == len(raw) and flags == 0xA, (text_offset, image_size, flags)
print("probe image: size", len(raw), "text_offset", text_offset, "flags", hex(flags))

kernel = boot_v4.compress_legacy_lz4(raw)
print("legacy-lz4 payload", len(kernel), "first4", kernel[:4].hex())

img = boot_v4.build_v4(tpl, kernel, b"", "boot-k70u-pstore-probe", preserve_avb_tail=True)
rep = boot_v4.verify_v4(img, kernel, b"", "boot-k70u-pstore-probe", template=tpl, preserve_avb_tail=True)
tail = boot_v4.avb_tail_offset(tpl, "stock")
rep.update({
    "template": tpl_path,
    "avb_tail_offset": hex(tail),
    "avb_tail_bytes": len(tpl) - tail,
    "tail_equal_to_template": img[tail:] == tpl[tail:],
    "decoded_probe_matches_raw": boot_v4.decompress_kernel(kernel)[0] == raw,
    "pmsg_base": "0x480f0000",
    "pmsg_marker": "K70U_AVB_PMSG_ENTRY_V1",
    "delay_seconds": 20,
    "device_tested": False,
})
dst = os.path.join(out, "boot-k70u-pstore-probe-20s.img")
open(dst, "wb").write(img)
open(os.path.join(out, "probe-report.json"), "w").write(json.dumps(rep, indent=2) + "\n")
print(json.dumps(rep, indent=2))
PY

echo "=== 5) 产物 ==="
ls -l "$OUT"/*.img
sha256sum "$OUT"/boot-k70u-pstore-probe-20s.img
