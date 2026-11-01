#!/bin/bash
# 初始化子模块（Mu_Basecore 私有走 SSH，其余走代理 https）
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
cd "$U" || exit 1

echo "=== DeviceBuild.py 依赖片段 ==="
sed -n '28,72p' Platforms/Xiaomi/rothkoPkg/DeviceBuild.py

export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ServerAliveInterval=15 -o ProxyCommand="/usr/bin/python3 /home/ubuntu/bin/proxyconnect.py %h %p"'
export https_proxy=http://172.30.32.1:15537
export http_proxy=http://172.30.32.1:15537

echo
echo "=== 初始化子模块 ==="
git -c url."git@github.com:".insteadOf="https://github.com/" \
    submodule update --init --recursive --depth 1 --progress 2>&1 | \
    tr '\r' '\n' | grep -E "Submodule|Cloning|Receiving objects: *100%|fatal|error" | tail -20

echo
echo "=== 子模块结果 ==="
for d in Mu_Basecore Silicium-ACPI Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl; do
  printf "%-58s " "$d"
  if [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
    echo "ok  $(git -C "$d" log --oneline -1 2>/dev/null)"
  else
    echo "空"
  fi
done
