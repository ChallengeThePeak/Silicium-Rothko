#!/bin/bash
set -u
export PATH=/home/ubuntu/bin:$PATH
W=/mnt/d/漏洞/UNIXNU/适配K70U

echo "=== mediatek-drm.ko 是否在本地 ==="
ls -l "$W/work/modules/lib/modules/mediatek-drm.ko" 2>/dev/null | awk '{print $5, $9}' || echo "缺失"

echo
echo "=== 工作区里的 LK 日志转储（含 OVL/DSI 关键字的文件）==="
rg -l -i "DSI_tx_buf_rw|disp-ovl|OVL_CON|src_con|L_CON" "$W/work" "$W/reports" 2>/dev/null | head -12

echo
echo "=== LK 镜像 ==="
ls -l /mnt/i/刷机/*/lk.img 2>/dev/null | head -5

echo
echo "=== mediatek-drm.ko 里的 OVL 相关符号 ==="
if [ -f "$W/work/modules/lib/modules/mediatek-drm.ko" ]; then
  llvm-nm --defined-only "$W/work/modules/lib/modules/mediatek-drm.ko" 2>/dev/null | rg -i "ovl.*(config|layer|set|enable)|mtk_disp_ovl" | head -20
fi
