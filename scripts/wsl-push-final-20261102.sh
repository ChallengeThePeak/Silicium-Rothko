#!/bin/bash
set -u
export PATH="$HOME/bin:$PATH"
R=/home/ubuntu/rothko-upstream-20261102/uefi-full
LOG=/mnt/d/漏洞/UNIXNU/适配K70U/logs/push.log
: > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }

say "=== 1) 代理探测 ==="
if timeout 20 curl -sS -o /dev/null -w "%{http_code}\n" -x http://172.28.224.1:15537 \
     --connect-timeout 12 https://github.com 2>/dev/null | grep -q 200; then
  say "relay 可用 → 使用 ProxyCommand"
  cat > ~/.ssh/config <<'EOF'
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
else
  say "relay 不可用 → 直连"
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
fi

say ""
say "=== 2) SSH 认证 ==="
timeout 60 ssh -o BatchMode=yes -T git@github.com 2>&1 | head -2 | tee -a "$LOG"

say ""
say "=== 3) Mu_Basecore 推送 ==="
cd "$R/Mu_Basecore" || exit 1
git remote -v | head -2 | tee -a "$LOG"
timeout 300 git push -u origin k70u-port-20261102 2>&1 | tail -5 | tee -a "$LOG"

say ""
say "=== 4) uefi-full 推送 uefi/rothko ==="
cd "$R" || exit 1
timeout 600 git push origin uefi/rothko 2>&1 | tail -5 | tee -a "$LOG"

say ""
say "=== 5) 试推 main（非快进会被拒绝）==="
timeout 300 git push origin HEAD:main 2>&1 | tail -5 | tee -a "$LOG"

say ""
say "=== 6) 远端分支确认 ==="
timeout 120 git ls-remote --heads origin 2>&1 | grep -E "rothko|main" | head -6 | tee -a "$LOG"
say "DONE"
