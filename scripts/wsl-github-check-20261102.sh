#!/bin/bash
set -u
export PATH="$HOME/bin:$PATH"
echo "=== WSL ssh config ==="
cat ~/.ssh/config 2>/dev/null | head -12
echo
echo "=== WSL GitHub SSH 认证 ==="
timeout 30 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | head -3
echo
echo "=== WSL gh / token ==="
command -v gh || echo "no gh"
ls ~/.config/gh 2>/dev/null | head -3 || true
env | grep -i -E "GITHUB|GH_TOKEN" | sed 's/=.*/=<set>/' | head -5
echo
echo "=== WSL git 版本与仓库可见性 ==="
git --version
cd "/mnt/d/漏洞/UNIXNU/适配K70U" 2>/dev/null || exit 0
git status --porcelain | head -3
git rev-parse --abbrev-ref HEAD
