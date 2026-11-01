#!/bin/bash
# 回滚 pmsg 基址改动（恢复上游偏移），保留 BdsEntry 的热复位
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
LIB="$U/Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c"
BDS="$U/Mu_Basecore/MdeModulePkg/Universal/BdsDxe/BdsEntry.c"

echo "=== 回滚前的 pstore 常量 ==="
rg -n "PSTORE_PMSG_BASE_KERNEL|PSTORE_PMSG_BASE_LEGACY" "$LIB" | head -4

# 1) 去掉双写包装，恢复单写（PSTORE_BASE + PSTORE_PMSG_OFFSET）
python3 - "$LIB" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()

# 删掉新增的两个常量定义块
import re
s = re.sub(r"\n//\n// \[k70u-fix 2026-11-02\] The kernel owns this region as ramoops:.*?#define PSTORE_PMSG_BASE_LEGACY  \(PSTORE_BASE \+ PSTORE_PMSG_OFFSET\)", "", s, flags=re.S)

# 包装函数改回直接写
s = s.replace(
    "PstoreWriteAt (\n  IN CONST UINT8  *Data,\n  IN UINTN         Length,\n  IN UINTN         Base\n  )",
    "PstoreWrite (\n  IN CONST UINT8  *Data,\n  IN UINTN         Length\n  )",
    1,
)
s = s.replace(
    "  Buffer   = (PSTORE_BUFFER *)(UINTN)Base;",
    "  Buffer   = (PSTORE_BUFFER *)(UINTN)(PSTORE_BASE + PSTORE_PMSG_OFFSET);",
    1,
)
s = s.replace(
    "STATIC\nVOID\nPstoreWrite (\n  IN CONST UINT8  *Data,\n  IN UINTN         Length\n  )\n{\n  PstoreWriteAt (Data, Length, PSTORE_PMSG_BASE_KERNEL);\n  PstoreWriteAt (Data, Length, PSTORE_PMSG_BASE_LEGACY);\n}\n\n",
    "",
    1,
)
open(p, "w", encoding="utf-8").write(s)
print("reverted pstore base")
PY

echo "=== 回滚后 ==="
rg -n "PstoreWrite|PSTORE_BASE|PSTORE_PMSG_OFFSET" "$LIB" | head -8
echo "--- 不应再有 BASE_KERNEL ---"
rg -c "PSTORE_PMSG_BASE_KERNEL" "$LIB" || echo "0 (已清除)"

echo
echo "=== 热复位必须保留 ==="
rg -n "K70U-BDS" "$BDS" | head -3
