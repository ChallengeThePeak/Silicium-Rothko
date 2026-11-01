#!/bin/bash
# 探测宿主代理可达性 + 克隆进度（无引号嵌套，供 wsl 直接执行）
set -u

HOST_NS=""
if [ -f /etc/resolv.conf ]; then
  HOST_NS=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
fi
echo "resolv_nameserver=$HOST_NS"

GW_HEX=$(awk '$2=="00000000" {print $3; exit}' /proc/net/route)
echo "gateway_hex=$GW_HEX"

if [ -n "$GW_HEX" ]; then
  GW_DEC=$((16#$GW_HEX))
  GW=$(printf "%d.%d.%d.%d" $(( (GW_DEC>>0)&255 )) $(( (GW_DEC>>8)&255 )) $(( (GW_DEC>>16)&255 )) $(( (GW_DEC>>24)&255 )))
  echo "gateway=$GW"
fi

for ip in "$HOST_NS" "${GW:-}"; do
  [ -z "$ip" ] && continue
  echo "--- proxy try http://$ip:55376 ---"
  timeout 10 curl -sS -x "http://$ip:55376" -o /dev/null -w "  github_code=%{http_code} time=%{time_total}s\n" https://github.com 2>&1 | tail -2
  timeout 10 curl -sS -x "http://$ip:55376" -o /dev/null -w "  api_code=%{http_code} time=%{time_total}s\n" https://api.github.com/users/ChallengeThePeak 2>&1 | tail -2
done

echo "--- direct baseline ---"
timeout 10 curl -sS -o /dev/null -w "  direct_github=%{http_code} time=%{time_total}s\n" https://github.com 2>&1 | tail -1

echo "--- clone state ---"
du -sh /home/ubuntu/rothko-upstream-20261102/Silicium-Rothko 2>/dev/null
ls -1 /home/ubuntu/rothko-upstream-20261102/Silicium-Rothko 2>/dev/null | head -5
echo "--- git processes ---"
ps -eo pid,etime,args 2>/dev/null | grep -c "[g]it-remote-ssh\|[g]it clone"
