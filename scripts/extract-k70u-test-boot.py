#!/usr/bin/env python3
"""Extract a uniquely size-matched LK candidate fragment with raw byte offsets."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct


KERNEL = rb"boot_linux_fdt:\d+: kernel_sz=(0x[0-9a-fA-F]+)"
START = rb"PL_LOG_STORE:(?:set ram_header->sig| check once,)"
FLASH = rb"fastboot: flash:boot_[ab]\[len:\d+\]"
IMPORTANT = (
    rb"Ready to boot linux[^\r\n\0]*",
    rb"\[AVB\] (?:img_auth_required|avb_ret)[^\r\n\0]*",
    rb"load_bootinfo_from_hdr:[^\r\n\0]*",
    KERNEL,
    rb"DT overlay ok[^\r\n\0]*",
    rb"boot_linux_fdt:\d+: decompress kernel image[^\r\n\0]*",
    rb"\[PROFILE\] ::: decompress_kernel[^\r\n\0]*",
    rb"io_task_callback:[^\r\n\0]*",
    rb"panic_header\.[^\r\n\0]*",
    rb"kedump[^\r\n\0]*TFA_DEBUG_BUF.gz[^\r\n\0]*",
)


def save(path, data):
    with path.open("xb") as stream:
        stream.write(data)


def readable(data, base):
    return "".join(f"{base + match.start():#010x} {match.group().decode('ascii')}\n"
                   for match in re.finditer(rb"[\x20-\x7e\t]{4,}", data)).encode("ascii")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists() or args.output.is_symlink():
        parser.error("output directory must be new")
    image = args.candidate.read_bytes()
    if image[:8] != b"ANDROID!" or struct.unpack_from("<I", image, 40)[0] != 4:
        parser.error("candidate must have an Android boot v4 header")
    expected = struct.unpack_from("<I", image, 8)[0]
    raw = args.raw.read_bytes()
    records = list(re.finditer(KERNEL, raw))
    matches = [item for item in records if int(item[1], 16) == expected]
    if len(matches) != 1:
        parser.error(f"expected one matching candidate-size record, found {len(matches)}")
    anchor = matches[0].start()
    starts = [match.start() for match in re.finditer(START, raw)]
    begin = max((offset for offset in starts if offset < anchor), default=0)
    end = min((offset for offset in starts if offset > anchor), default=len(raw))
    flashes = [match.start() for match in re.finditer(FLASH, raw)]
    before = max((offset for offset in flashes if offset < anchor), default=None)
    after = min((offset for offset in flashes if offset > anchor), default=None)
    post_end = after if after is not None else end
    hits = []
    for pattern in IMPORTANT:
        for match in re.finditer(pattern, raw[begin:post_end]):
            offset = begin + match.start()
            hits.append({"offset": offset, "offset_hex": hex(offset),
                         "region": "candidate_lk_fragment" if offset < end else "following_reset_text",
                         "text": match.group().decode("ascii")})
    hits.sort(key=lambda item: item["offset"])

    args.output.mkdir(parents=True)
    fragment = raw[begin:end]
    save(args.output / "candidate-lk-fragment.bin", fragment)
    save(args.output / "candidate-lk.txt", readable(fragment, begin))
    if after is not None and after > end:
        save(args.output / "after-test-before-restore.txt", readable(raw[end:after], end))
    for label, offset in (("preceding-flash", before), ("following-restore", after)):
        if offset is None:
            continue
        reboot = raw.find(b"rebooting the device", offset)
        stop = min(len(raw), reboot + 160) if reboot >= 0 else min(len(raw), offset + 4096)
        lo = max(0, offset - 750)
        save(args.output / f"{label}.txt", readable(raw[lo:stop], lo))
    result = {
        "raw_path": str(args.raw.resolve()), "raw_sha256": hashlib.sha256(raw).hexdigest(),
        "candidate_image": str(args.candidate.resolve()),
        "candidate_image_sha256": hashlib.sha256(image).hexdigest(),
        "candidate_kernel_size": expected, "candidate_kernel_size_hex": hex(expected),
        "kernel_anchor": hex(anchor), "fragment_start": hex(begin), "fragment_end_exclusive": hex(end),
        "fragment_sha256": hashlib.sha256(fragment).hexdigest(),
        "preceding_flash": hex(before) if before is not None else None,
        "following_flash_restore_context": hex(after) if after is not None else None,
        "kernel_records": [{"offset": hex(item.start()), "size_hex": item[1].decode("ascii"),
                            "selected": item.start() == anchor} for item in records],
        "important_lines": hits,
        "limitations": [
            "Size matching plus the user's timeline identifies the intended retained LK record; it is not a flash hash.",
            "PL text boundaries and flash adjacency are physical positions, not validated whole-ring chronology.",
            "LK decompression completion does not by itself prove BootShim, SEC or DXE executed.",
            "Following reset text is not an admitted AEE payload; do not invent PC/ELR/FAR from it.",
        ],
    }
    save(args.output / "selection.json", (json.dumps(result, indent=2) + "\n").encode("ascii"))
    print(json.dumps({key: result[key] for key in (
        "raw_sha256", "candidate_image_sha256", "candidate_kernel_size_hex", "kernel_anchor",
        "fragment_start", "fragment_end_exclusive", "preceding_flash", "following_flash_restore_context",
        "important_lines",
    )}, indent=2))


if __name__ == "__main__":
    main()
