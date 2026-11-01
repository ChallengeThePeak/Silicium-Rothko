#!/bin/bash
# 无 venv 情况下用 --user --break-system-packages 装依赖
set -u
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
cd "$U" || exit 1
MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple

echo "=== pip 状态 ==="
python3 -m pip --version 2>&1 | tail -2

if ! python3 -m pip --version >/dev/null 2>&1; then
  echo "=== 尝试 apt 安装 python3-pip / python3-venv ==="
  sudo -n apt-get install -y python3-pip python3.12-venv 2>&1 | tail -5
fi

echo "=== 安装 requirements ==="
PIP_NO_CACHE_DIR=1 python3 -m pip install --no-cache-dir --user --break-system-packages \
  --index-url "$MIRROR" --trusted-host pypi.tuna.tsinghua.edu.cn \
  -r pip-requirements.txt 2>&1 | tail -12

echo "=== 校验 ==="
python3 -c "import edk2toolext, edk2toollib; print('edk2toolext ok')" 2>&1 | tail -2
python3 -c "import edk2toolext; print(edk2toolext.__file__)" 2>&1 | tail -1
