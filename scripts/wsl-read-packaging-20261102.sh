#!/bin/bash
# 读取上游打包链：容器审计全文 + 工具清单 + 引导头路由决策
set -u
cd /home/ubuntu/rothko-upstream-20261102/Silicium-Rothko || exit 1

echo "=== tools 目录 ==="
ls -l tools
echo
echo "=== BOOT_CONTAINER_AUDIT.md 全文 ==="
cat BOOT_CONTAINER_AUDIT.md
