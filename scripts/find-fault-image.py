#!/usr/bin/env python3
"""Find which loaded image the faulting PC could belong to.

The beacon gives an absolute ELR (e.g. 0x43b86bd4) but not the image base, and
DXE assigns those at runtime. Every image is loaded on a 4 KiB boundary, so the
RVA is always  ELR & 0xfff  plus k*0x1000. This scans every built .efi for a
memory access at such an RVA and decodes it far enough to tell whether it can
produce the observed FAR.

Usage:  find-fault-image.py <build-AARCH64-dir> <ELR> [--verbose]
"""
import pathlib
import struct
import sys

# ---- tiny A64 load/store classifier (enough to spot the faulting access) ----

def decode_loadstore(w: int):
    """Return (kind, size_bytes, offset_or_None, rn, rt) or None if not a L/S."""
    op29_27 = (w >> 27) & 0x7
    if op29_27 not in (0b111, 0b101):
        return None

    size = w >> 30                      # 00 byte, 01 half, 10 word, 11 dword
    nbytes = 1 << size
    rn = (w >> 5) & 0x1F
    rt = w & 0x1F

    if op29_27 == 0b101:                # load/store pair
        imm7 = (w >> 15) & 0x7F
        if imm7 & 0x40:
            imm7 -= 0x80
        return ("pair", nbytes, imm7 * nbytes, rn, rt)

    if (w >> 24) & 1:                   # single register, 1x00...
        mode = (w >> 10) & 0x3
        if (w >> 21) & 1:               # register offset
            rm = (w >> 16) & 0x1F
            return ("reg-offset", nbytes, None, rn, rm)
        if mode == 0b01:                # unsigned immediate
            return ("uimm", nbytes, ((w >> 10) & 0xFFF) * nbytes, rn, rt)
        imm9 = (w >> 12) & 0x1FF       # unscaled / pre / post index
        if imm9 & 0x100:
            imm9 -= 0x200
        return ("imm9", nbytes, imm9, rn, rt)

    return None


def pe_sections(path: pathlib.Path):
    d = path.read_bytes()
    if d[:2] != b"MZ":
        return d, []
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    coff = pe + 4
    nsec, = struct.unpack_from("<H", d, coff + 2)
    optsz, = struct.unpack_from("<H", d, coff + 16)
    opt = coff + 20
    magic, = struct.unpack_from("<H", d, opt)
    size_of_image, = struct.unpack_from("<I", d, opt + 56)
    sec = opt + optsz
    out = []
    for i in range(nsec):
        o = sec + i * 40
        name = d[o:o + 8].rstrip(b"\0").decode("ascii", "replace")
        vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", d, o + 8)
        chars, = struct.unpack_from("<I", d, o + 36)
        if chars & 0x20000000:          # IMAGE_SCN_MEM_EXECUTE
            out.append((name, vaddr, max(vsize, rawsize), rawptr))
    return d, out, size_of_image


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    root = pathlib.Path(sys.argv[1])
    elr = int(sys.argv[2], 0)
    verbose = "--verbose" in sys.argv
    page_off = elr & 0xFFF

    hits = []
    for efi in sorted(root.rglob("*.efi")):
        try:
            d, exec_secs, soi = pe_sections(efi)
        except Exception:
            continue
        if not exec_secs:
            continue
        for name, vaddr, vsize, rawptr in exec_secs:
            # First RVA at or above this section's start that matches the page offset.
            rva = page_off
            if rva < vaddr:
                rva += ((vaddr - rva + 0xFFF) // 0x1000) * 0x1000
            while rva + 4 <= vaddr + vsize:
                off = rawptr + (rva - vaddr)
                w, = struct.unpack_from("<I", d, off)
                dec = decode_loadstore(w)
                if dec is not None:
                    kind, nb, ofs, rn, rt = dec
                    base = elr - rva
                    hits.append((efi.relative_to(root), rva, base, w, kind, nb, ofs, rn, rt))
                rva += 0x1000

    print(f"ELR = {elr:#x}   page offset = {page_off:#x}")
    print(f"load/store candidates: {len(hits)}\n")

    for rel, rva, base, w, kind, nb, ofs, rn, rt in hits:
        # A FAR of 0xFFFFFFFFFFFFFFF1 = -15 means base_reg + offset == -15.
        # Keep the ones where that is at least conceivable.
        if ofs is None:
            tag = "reg-offset"
        elif ofs == -15:
            tag = "offset == -15 (base 0)"
        elif ofs == 0:
            tag = "offset 0"
        elif ofs < 0:
            tag = f"offset {ofs}"
        else:
            tag = f"offset +{ofs}"
        if verbose or ofs is None or ofs <= 0:
            print(f"{rel}")
            print(f"    RVA {rva:#08x}  implied base {base:#012x}  {w:08x}  {kind}/{nb}B rn=x{rn} rt=x{rt}  {tag}")


if __name__ == "__main__":
    sys.exit(main())
