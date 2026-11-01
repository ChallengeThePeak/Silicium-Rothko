#!/bin/bash
# Static analysis of a packed rothko boot image: unpack the payload and show
# what the BootShim actually jumps to.
#
# Usage: analyse-bootimg.sh [image]
set -uo pipefail

IMG="${1:-/mnt/d/漏洞/UNIXNU/适配K70U/bringup/boot-rothko-uefi-10-dali.img}"
WORK=/home/ubuntu/rothko/analyse
mkdir -p "$WORK"

python3 - "$IMG" "$WORK" <<'PY'
import gzip, sys, pathlib
img = pathlib.Path(sys.argv[1]); work = pathlib.Path(sys.argv[2])
d = img.read_bytes()
raw = gzip.decompress(d[4096:])
(work / "payload.bin").write_bytes(raw)
(work / "shim.bin").write_bytes(raw[:192])
(work / "fd.bin").write_bytes(raw[192:])
print(f"payload {len(raw)} B, shim 192 B, fd {len(raw)-192} B")
PY

echo
echo "=== shim disassembly (first 192 bytes) ==="
llvm-objdump -D -b binary --triple=aarch64 -mattr=+v8a "$WORK/shim.bin" 2>/dev/null \
  || objdump -D -b binary -m aarch64 "$WORK/shim.bin"

echo
echo "=== shim words ==="
od -A d -t x4 -N 64 "$WORK/shim.bin"

echo
echo "=== FD first 128 bytes ==="
od -A d -t x1 -N 128 "$WORK/fd.bin"
