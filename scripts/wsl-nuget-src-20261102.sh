#!/bin/bash
set -u
P=/home/ubuntu/.local/lib/python3.12/site-packages/edk2toolext
echo "=== bin/nuget.py ==="
sed -n '1,80p' "$P/bin/nuget.py" 2>/dev/null
echo
echo "=== NugetDependency.GetNugetCmd 片段 ==="
sed -n '55,120p' "$P/environment/extdeptypes/nuget_dependency.py" 2>/dev/null
