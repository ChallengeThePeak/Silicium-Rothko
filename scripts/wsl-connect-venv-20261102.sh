#!/bin/bash
set -u
echo "=== 连通性 ==="
for u in https://github.com https://api.github.com https://pypi.org/simple/; do
  code=$(timeout 20 curl -sS -o /dev/null -w "%{http_code} %{time_total}" "$u" 2>/dev/null || echo "fail")
  echo "$u -> $code"
done

echo
echo "=== 现有 venv / edk2toolext ==="
ls -d /home/ubuntu/*venv* /home/ubuntu/rothko-upstream-20261102/uefi-full/.venv* 2>/dev/null
for p in /home/ubuntu/rothko-upstream-20261102/uefi-full/.venv-linux-build /home/ubuntu/.venv /home/ubuntu/venv; do
  if [ -x "$p/bin/python" ]; then
    printf "%s: " "$p"
    "$p/bin/python" -c "import edk2toolext, edk2toollib; print('edk2tool ok')" 2>&1 | tail -1
  fi
done
echo "--- 系统 python 是否已有 edk2toolext ---"
python3 -c "import edk2toolext; print('system ok')" 2>&1 | tail -1
