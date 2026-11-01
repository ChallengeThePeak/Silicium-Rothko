#!/bin/bash
# 建 venv 并从国内镜像装 edk2 构建依赖
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
cd "$U" || exit 1

echo "=== 镜像可达性 ==="
for u in https://pypi.tuna.tsinghua.edu.cn/simple/ https://mirrors.aliyun.com/pypi/simple/ https://pypi.org/simple/; do
  code=$(timeout 20 curl -sS -o /dev/null -w "%{http_code}" "$u" 2>/dev/null || echo fail)
  echo "$u -> $code"
done

MIRROR=""
for m in https://pypi.tuna.tsinghua.edu.cn/simple https://mirrors.aliyun.com/pypi/simple https://pypi.org/simple; do
  if timeout 15 curl -sS -o /dev/null "$m/" 2>/dev/null; then MIRROR="$m"; break; fi
done
echo "选用镜像: ${MIRROR:-none}"
[ -z "$MIRROR" ] && { echo "无可用 PyPI 镜像，停止"; exit 3; }

echo "=== 建 venv ==="
if [ ! -x .venv-linux-build/bin/python ]; then
  python3 -m venv .venv-linux-build
fi
. .venv-linux-build/bin/activate
python -V

echo "=== 安装依赖 ==="
PIP_NO_CACHE_DIR=1 python -m pip install --no-cache-dir -q --index-url "$MIRROR" --trusted-host $(echo "$MIRROR" | awk -F/ '{print $3}') -r pip-requirements.txt 2>&1 | tail -12
python -c "import edk2toolext, edk2toollib; print('edk2toolext ok')"
