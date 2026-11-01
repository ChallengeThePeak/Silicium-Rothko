#!/bin/bash
# 内存表：挖出显示 MMIO 区 + 加回 Display Reserved 帧缓冲
set -u
export PATH=/home/ubuntu/bin:$PATH
U=/home/ubuntu/rothko-upstream-20261102/uefi-full
M="$U/Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c"
Q=/home/ubuntu/quarantine
cp -f "$M" "$Q/MemoryMapLib.c.pre-display-$(date +%Y%m%d-%H%M%S)"

python3 - "$M" <<'PY'
import re, sys
p = sys.argv[1]
src = open(p, encoding="utf-8").read()

if '"Display Reserved"' in src:
    print("already patched"); raise SystemExit

REG = re.compile(
    r'^(?P<ind>\s*)\{"(?P<name>[^"]+)",\s*0x(?P<base>[0-9A-Fa-f]+),\s*0x(?P<len>[0-9A-Fa-f]+),\s*'
    r'(?P<hob>\w+),\s*(?P<rtype>\w+),\s*(?P<rattr>\w+),\s*(?P<mem>\w+),\s*(?P<arm>\w+)\},(?P<tail>.*)$',
    re.M)

# 显示 MMIO：与已验证的旧树一致（MMSYS / MUTEX / OVLSYS / DISPSYS1 / DSC0 / DSI0 / MIPI TX0）
MMIO = [
    ("Display MMSYS",    0x14000000, 0x00001000),
    ("MUTEX DISPSYS0",   0x14001000, 0x00001000),
    ("Display DISPSYS1", 0x14200000, 0x00001000),
    ("MUTEX DISPSYS1",   0x14201000, 0x00001000),
    ("DSC0",             0x14206000, 0x00001000),
    ("DSI0",             0x1420A000, 0x00001000),
    ("Display OVLSYS0",  0x14400000, 0x00010000),
    ("Display OVLSYS1",  0x14600000, 0x00010000),
    ("MIPI TX0",         0x11E90000, 0x00001000),
]
# 帧缓冲 carveout：LK 交接的 atag,videolfb
FB_BASE, FB_SIZE = 0xFD91F000, 0x026E0000

holes = sorted((b, b + l) for _, b, l in MMIO)

def split_region(name, base, length, ind, tail):
    """把 holes 从 [base, base+length) 里挖掉，返回若干 (base, length)"""
    pieces = [(base, base + length)]
    for hb, he in holes:
        out = []
        for pb, pe in pieces:
            if he <= pb or hb >= pe:
                out.append((pb, pe)); continue
            if pb < hb:
                out.append((pb, hb))
            if he < pe:
                out.append((he, pe))
        pieces = out
    return [(pb, pe - pb) for pb, pe in pieces if pe > pb]

out_lines = []
added = 0
for line in src.splitlines():
    m = REG.match(line)
    if m and m.group("hob") == "AddMem" and m.group("rtype") == "SYS_MEM":
        base = int(m.group("base"), 16)
        length = int(m.group("len"), 16)
        pieces = split_region(m.group("name"), base, length, m.group("ind"), m.group("tail"))
        if len(pieces) > 1:
            for i, (pb, pl) in enumerate(pieces):
                nm = m.group("name") if len(pieces) == 1 else f"{m.group('name')} {i}"
                out_lines.append(
                    f'{m.group("ind")}{{"{nm}", 0x{pb:X}, 0x{pl:X}, AddMem, SYS_MEM, '
                    f'{m.group("rattr")}, {m.group("mem")}, {m.group("arm")}}},')
            added += len(pieces)
            continue
    out_lines.append(line)

src = "\n".join(out_lines) + ("\n" if src.endswith("\n") else "")

# 追加显示 MMIO 与帧缓冲
new_regions = []
for nm, b, l in MMIO:
    new_regions.append(f'  {{"{nm}", 0x{b:X}, 0x{l:X}, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE}},')
new_regions.append(
    f'  {{"Display Reserved", 0x{FB_BASE:X}, 0x{FB_SIZE:X}, AddMem, MEM_RES, SYS_MEM_TESTED, Reserv, WRITE_THROUGH}},')

marker = "\n};"
idx = src.rfind(marker)
if idx < 0:
    sys.exit("array end not found")
block = ("\n  //\n"
         "  // [k70u-fix 2026-11-02] Display plumbing for RothkoDisplayDxe.\n"
         "  // The MMIO windows below are the ones the driver probes (MMSYS, the two\n"
         "  // MUTEX banks, OVLSYS0/1, DISPSYS1, DSC0, DSI0) and were validated on\n"
         "  // dali (MT6991) and against the stock LK handoff for rothko.\n"
         "  // Display Reserved is the framebuffer carveout LK hands over in\n"
         "  // atag,videolfb: base 0xFD91F000, size 0x26E0000 (1220x2712, 32bpp).\n"
         "  //\n"
         + "\n".join(new_regions) + "\n")
src = src[:idx] + block + src[idx:]
open(p, "w", encoding="utf-8").write(src)
print(f"memory map patched, free pieces added: {added}")
PY

echo "=== 结果 ==="
rg -n "Display|MIPI|DSI0|MUTEX|DSC0|OVLSYS" "$M" | head -20
