#!/bin/bash
# 修正上游不一致：UniXNUConfig.dsc.inc 引用了未声明的 PCD（无任何消费者）
set -u
P=/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/UniXNUConfig.dsc.inc
Q=/home/ubuntu/quarantine
mkdir -p "$Q"
cp -f "$P" "$Q/UniXNUConfig.dsc.inc.orig-$(date +%Y%m%d-%H%M%S)"

echo "=== 原文 ==="
cat "$P"

python3 - "$P" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
lines = s.splitlines()
out = []
for ln in lines:
    if "PcdUniXNURamDiskOffset" in ln or "PcdUniXNURamDiskSize" in ln:
        out.append("# [build-fix 2026-11-02] 该 PCD 未在任何 DEC 中声明，且无消费者，上游此处不一致；暂时注释")
        out.append("#" + ln.strip())
    else:
        out.append(ln)
open(p, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("已注释")
PY

echo "=== 修改后 ==="
cat "$P"
