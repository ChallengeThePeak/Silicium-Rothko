#!/bin/bash
# 接入用户下载的 mu_nasm 包：校验 -> 放入 NuGet 全局缓存 -> 补 mono 程序集
set -u
SRC="/mnt/c/Users/Administrator/Downloads/mu_nasm.20016.1.1 (1).nupkg"
WORK=/home/ubuntu/nuget-cache
mkdir -p "$WORK"
cp -f "$SRC" "$WORK/mu_nasm.20016.1.1.nupkg"
echo "=== 包校验 ==="
ls -l "$WORK/mu_nasm.20016.1.1.nupkg"
python3 - "$WORK/mu_nasm.20016.1.1.nupkg" <<'PY'
import sys, zipfile, hashlib
p = sys.argv[1]
data = open(p, "rb").read()
print("bytes", len(data), "sha256", hashlib.sha256(data).hexdigest())
print("zip magic", data[:4].hex())
z = zipfile.ZipFile(p)
names = z.namelist()
print("entries", len(names))
for n in names[:12]:
    print("  ", n)
print("has nuspec:", any(n.endswith(".nuspec") for n in names))
PY

echo
echo "=== 补 mono 程序集（之前中断）==="
cd /home/ubuntu/mono-debs || exit 1
PKGS="libmono-system-componentmodel-composition4.0-cil libmono-system-runtime-serialization4.0-cil libmono-system-net-http4.0-cil libmono-system-security4.0-cil libmono-system-xml4.0-cil libmono-system-numerics4.0-cil libmono-microsoft-csharp4.0-cil libmono-csharp4.0c-cil"
apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts \
  --no-breaks --no-replaces --no-enhances $PKGS 2>/dev/null \
  | grep -E '^[a-z0-9][a-z0-9.+-]*$' | sort -u > pkgs2.txt
echo "待下载 $(wc -l < pkgs2.txt) 个包"
timeout 900 apt-get download $(tr '\n' ' ' < pkgs2.txt) 2>&1 | tail -3
for d in *.deb; do dpkg -x "$d" /home/ubuntu/mono 2>/dev/null; done
echo "解包完成，deb 总数 $(ls *.deb | wc -l)"

echo
echo "=== mono 跑 NuGet（pytool 的调用方式）==="
export MONO_CFG_DIR=/home/ubuntu/mono/etc
export PATH=/home/ubuntu/mono/usr/bin:$PATH
export LD_LIBRARY_PATH=/home/ubuntu/mono/usr/lib
cp -f /home/ubuntu/nuget/NuGet-6.4.0.exe /home/ubuntu/nuget/NuGet.exe
timeout 90 mono /home/ubuntu/nuget/NuGet.exe locals global-packages -list 2>&1 | tail -4
