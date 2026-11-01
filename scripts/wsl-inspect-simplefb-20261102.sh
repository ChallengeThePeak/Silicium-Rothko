#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== SimpleFbDxe 文件 ==="
rg --files "$U/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe" 2>/dev/null

echo
echo "=== SimpleFbDxe 关键特征 ==="
for f in $(rg --files "$U/Silicon/Silicium/SiliciumPkg/Drivers/SimpleFbDxe" -g "*.c" -g "*.h" -g "*.inf" 2>/dev/null); do
  echo "--- $f"
  rg -n "GraphicsOutput|GopDxe|FrameBuffer|simple-framebuffer|SimpleFb|Refresh|DSI|0x1420|1220|2712|Dali|DALI|mutex|Mutex|Display Reserved" "$f" 2>/dev/null | head -18
done

echo
echo "=== 是否还有 RothkoDisplayDxe 源码（历史证据目录）==="
ls -d /home/ubuntu/rothko-evidence-20261101 2>/dev/null && \
  rg --files /home/ubuntu/rothko-evidence-20261101 2>/dev/null | rg -i "RothkoDisplay" | head -10
find /home/ubuntu -maxdepth 4 -iname "*RothkoDisplay*" 2>/dev/null | head -10
