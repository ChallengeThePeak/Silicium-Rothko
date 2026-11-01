#!/bin/bash
# 移除我先前加的 uefi-full/UniXNU 软链（移动到隔离目录，不删除），避免包路径歧义
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
if [ -L "$U/UniXNU" ]; then
  mv "$U/UniXNU" "$Q/UniXNU-symlink-$(date +%Y%m%d-%H%M%S)"
  echo "软链已移出 workspace"
else
  echo "workspace 内无 UniXNU 软链"
fi
ls -ld "$U/UniXNU" 2>/dev/null || echo "确认：workspace 下已无 UniXNU 目录/软链"

echo "=== 固定提交里该文件的真实名字 ==="
ls /home/ubuntu/UniXNU/package/UniXNUPkg/Library/UniXNULib/ | grep -i inf
ls -d /home/ubuntu/UniXNU/package/UniXNUPkg /home/ubuntu/UniXNU/package/UniXNUPkg/Library 2>&1
