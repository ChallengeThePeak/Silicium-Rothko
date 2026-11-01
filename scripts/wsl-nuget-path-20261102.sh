#!/bin/bash
set -u
P=/home/ubuntu/.local/lib/python3.12/site-packages/edk2toolext
echo "=== pytool 里 nuget 相关实现 ==="
grep -rn "nuget.exe\|nuget_download\|dist.nuget.org\|GetNugetExePath" "$P" 2>/dev/null | head -15
echo
echo "=== nuget 依赖实现片段 ==="
sed -n '1,60p' "$P/environment/extdeptypes/nuget_dependency.py" 2>/dev/null
echo
echo "=== 常见缓存位置 ==="
ls -l /home/ubuntu/.pytool 2>/dev/null | head; ls -l /home/ubuntu/.cache 2>/dev/null | head -5
