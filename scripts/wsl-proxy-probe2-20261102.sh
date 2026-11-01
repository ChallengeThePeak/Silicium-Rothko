#!/bin/bash
# 测试 WSL 经 Windows 中继访问代理，以及代理是否允许 CONNECT 到 github.com:22
GW=172.30.32.1
REL=15537

echo "=== 1) HTTPS via relay ==="
timeout 15 curl -sS -x "http://$GW:$REL" -o /dev/null \
  -w "  code=%{http_code} time=%{time_total}s\n" https://github.com 2>&1 | tail -2

echo "=== 2) CONNECT to github.com:22 via relay ==="
python3 - <<'PY'
import socket, sys
try:
    s = socket.create_connection(("172.30.32.1", 15537), timeout=15)
except Exception as e:
    print("  relay unreachable:", e); sys.exit(0)
req = ("CONNECT github.com:22 HTTP/1.1\r\nHost: github.com:22\r\n"
       "Proxy-Connection: keep-alive\r\n\r\n")
s.sendall(req.encode())
buf = b""
s.settimeout(20)
try:
    while b"\r\n\r\n" not in buf:
        d = s.recv(4096)
        if not d:
            break
        buf += d
except Exception as e:
    print("  read err:", e)
head = buf.split(b"\r\n\r\n")[0]
print("  proxy resp:", head.decode("latin1").replace("\r\n", " | ")[:200])
if b" 200" in head.split(b"\r\n")[0]:
    try:
        banner = s.recv(128)
        print("  ssh banner:", banner.decode("latin1").strip()[:80])
    except Exception as e:
        print("  banner err:", e)
PY

echo "=== 3) 克隆进度 ==="
du -sh /home/ubuntu/rothko-upstream-20261102/Silicium-Rothko 2>/dev/null
