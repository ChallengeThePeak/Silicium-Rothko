#!/usr/bin/env python3
"""Validate every MemoryMapLib descriptor against ArmMmuLib's page-alignment rule.

ArmMmuLibCore.c UpdateRegionMapping() rejects any region whose Address or
Length is not a multiple of EFI_PAGE_SIZE (4 KiB). A single offender makes
ArmConfigureMmu() fail, which makes SEC return early and spin forever at the
end of _ModuleEntryPoint -- indistinguishable from a hang.

Read-only.
"""
import re
import sys
import pathlib

SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                   "/home/ubuntu/rothko/Mu-Silicium/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c")

PAGE = 0x1000

text = SRC.read_text(encoding="utf-8", errors="replace")

# Match: {"Name", addr, len, ...}
ENTRY = re.compile(
    r'\{\s*"([^"]+)"\s*,\s*'
    r'(0x[0-9A-Fa-f]+|[A-Za-z_][A-Za-z0-9_]*)\s*,\s*'
    r'(0x[0-9A-Fa-f]+|[A-Za-z_][A-Za-z0-9_]*)\s*,'
)

# Resolve the two macros the file defines.
macros = {}
for m in re.finditer(r'#define\s+(\w+)\s+(0x[0-9A-Fa-f]+)ULL?', text):
    macros[m.group(1)] = int(m.group(2), 16)


def value(tok: str):
    if tok in macros:
        return macros[tok]
    try:
        return int(tok, 0)
    except ValueError:
        return None


print(f"file: {SRC.name}")
print(f"macros: {macros}")
print()
print(f"{'name':<22} {'address':>12} {'length':>10}  {'addr ok':>8} {'len ok':>7}")
print("-" * 66)

bad = []
for m in ENTRY.finditer(text):
    name, a_tok, l_tok = m.groups()
    addr, length = value(a_tok), value(l_tok)
    if addr is None or length is None:
        print(f"{name:<22} {'?':>12} {'?':>10}  (unresolved)")
        continue
    a_ok = (addr % PAGE) == 0
    l_ok = (length % PAGE) == 0
    print(f"{name:<22} {addr:#12x} {length:#10x}  {'yes' if a_ok else 'NO':>8} {'yes' if l_ok else 'NO':>7}")
    if not (a_ok and l_ok):
        bad.append((name, addr, length))

print()
if bad:
    print("FAIL: these descriptors violate 4 KiB alignment and will make")
    print("      ArmConfigureMmu() return EFI_INVALID_PARAMETER:")
    for name, addr, length in bad:
        rounded = (length + PAGE - 1) & ~(PAGE - 1)
        print(f"  - {name}: addr={addr:#x} len={length:#x} -> len should be {rounded:#x}")
    sys.exit(1)

print("PASS: every descriptor is page aligned")
