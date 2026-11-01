#!/bin/bash
set -u
P=/home/ubuntu/.local/lib/python3.12/site-packages/edk2toolext
echo "=== NugetDependency 的安装路径与检查逻辑 ==="
grep -nE "install_path|_check_installed|def install|def fetch|OutputDirectory|state|workspace" \
  "$P/environment/extdeptypes/nuget_dependency.py" | head -25
echo
echo "=== ExternalDependency 里 install_path 定义 ==="
grep -nE "install_path|def _check_installed|def install|state" "$P/environment/external_dependency.py" | head -20
echo
echo "=== 工作区里已有的 ext_dep 状态文件 ==="
find /home/ubuntu/rothko-upstream-20261102/uefi-full -maxdepth 2 -name "*.state" -o -maxdepth 2 -name "*_extdep*" 2>/dev/null | head -10
ls -d /home/ubuntu/rothko-upstream-20261102/uefi-full/*_extdep* 2>/dev/null | head -5
