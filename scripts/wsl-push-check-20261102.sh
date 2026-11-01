#!/bin/bash
set -u
export PATH="$HOME/bin:$PATH"
R=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=== 恢复 ssh config（去掉 ProxyCommand）==="
cat > ~/.ssh/config <<'EOF'
Host github.com
    HostName ssh.github.com
    Port 443
    User git
    IdentityFile ~/.ssh/id_ed25519_wsl
    IdentitiesOnly yes
    ServerAliveInterval 30

Host ssh.github.com
    HostName ssh.github.com
    Port 443
    User git
EOF
echo "已恢复"

echo
echo "=== 直连看远端分支 ==="
cd "$R/Mu_Basecore" || exit 1
echo "--- Mu_Basecore remote ---"
git remote -v | head -2
timeout 60 git ls-remote --heads origin 2>&1 | head -8
echo "--- 我们的提交在不在 ---"
timeout 60 git ls-remote --heads origin 2>&1 | grep -i k70u || echo "远端暂无 k70u 分支"

echo
cd "$R" || exit 1
echo "--- uefi-full remote ---"
git remote -v | head -2
timeout 90 git ls-remote --heads origin 2>&1 | head -10
