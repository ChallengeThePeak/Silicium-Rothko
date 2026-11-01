#!/bin/bash
# 给 GitHub SSH 挂上代理（Clash relay），并测试连通性
set -u
export PATH="$HOME/bin:$PATH"
CFG=~/.ssh/config
BAK=~/.ssh/config.bak-$(date +%Y%m%d-%H%M%S)
cp "$CFG" "$BAK"

cat > "$CFG" <<EOF
Host github.com
    HostName ssh.github.com
    Port 443
    User git
    IdentityFile ~/.ssh/id_ed25519_wsl
    IdentitiesOnly yes
    ServerAliveInterval 30
    ProxyCommand python3 "/mnt/d/漏洞/UNIXNU/适配K70U/scripts/proxyconnect.py" %h %p

Host ssh.github.com
    HostName ssh.github.com
    Port 443
    User git
EOF

echo "=== 新 ssh config ==="
cat "$CFG"
echo
echo "=== 通过代理测试认证 ==="
PWF_PROXY_HOST=172.28.224.1 PWF_PROXY_PORT=15537 timeout 40 ssh -o BatchMode=yes -T git@github.com 2>&1 | head -3
