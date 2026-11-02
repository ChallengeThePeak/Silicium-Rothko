#!/usr/bin/env python3
"""Repair the refresh-tick log: an unquoted heredoc ate the C escape, splitting
the format string across two lines, and a duplicate mRefreshCount declaration
was added on top of the one that already existed."""
from pathlib import Path
import sys

P = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c")
t = P.read_text(encoding="utf-8")

# 1. drop the duplicate declaration we introduced
dup = "STATIC BOOLEAN mRefreshActive;\nSTATIC UINT32  mRefreshCount;\n"
if dup in t:
    t = t.replace(dup, "STATIC BOOLEAN mRefreshActive;\n", 1)
    print("removed duplicate mRefreshCount declaration")
else:
    print("note: duplicate declaration pattern not found")

# 2. repair the split format string
broken = '''      "ROTHKO: refresh %u frames, dsi status=%08x
",'''
fixed = '      "ROTHKO: refresh %u frames, dsi status=%08x\\n",'
if broken in t:
    t = t.replace(broken, fixed, 1)
    print("repaired format string")
elif 'dsi status=%08x\\n' in t:
    print("note: format string already correct")
else:
    print("ERROR: could not locate the broken format string")
    sys.exit(2)

P.write_text(t, encoding="utf-8")

# sanity report
lines = t.split("\n")
dups = [i + 1 for i, l in enumerate(lines) if l.strip().startswith("STATIC") and "mRefreshCount" in l]
print("mRefreshCount declarations at lines:", dups)
