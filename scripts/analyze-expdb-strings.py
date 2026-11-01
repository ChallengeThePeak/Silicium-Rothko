#!/usr/bin/env python3
"""Inventory retained MTK log fragments without mistaking text order for boots."""

import argparse
import hashlib
import json
import re
from pathlib import Path


MARKERS = {
    "flash_boot_a": r"fastboot: flash:boot_a\[",
    "flash_boot_b": r"fastboot: flash:boot_b\[",
    "expdb_erase_record": r"fastboot: erase:expdb\[",
    "reboot_request": r"^rebooting the device$",
    "early_save": r"^PL_LOG_STORE early_save_pllog,",
    "sram_save": r"^PL_LOG_STORE:save last preload sram log",
    "boot_device_ok": r"^\[PLFM\] Init Boot Device: OK\(0\)",
    "wdt_init_timing": r"^#T#WDT_INIT=",
    "ram_console_reset_status": r"^RAM_CONSOLE wdt status ",
    "raw_lastpc": r"^\[LASTPC\]CPU0 pc=",
    "lk_mt_boot": r"^starting app mt_boot$",
    "lk_wait": r"wait_for_boot_linux:.*Wait for boot linux event",
    "lk_ready": r"Ready to boot linux",
    "kernel_size": r"kernel_sz=",
    "kernel_decompress": r"decompress kernel image",
    "lk_final_jump": r"lk finished.*jump to linux kernel|booting linux @",
    "atf_cpu_pc": r"^(?!\[LASTPC\]).*(?:CPU PC|CPU\s*\d+\s*PC\s*[=:])",
    "atf_wdt_length": r"WDT LENGTH",
    "tfa_section_name": r"TFA_DEBUG_BUF\.gz",
    "uefi_text": r"ROTHKO:|BootShim|Silicium|CoreFreePool|UEFI|DXE",
}
PATTERNS = {key: re.compile(value, re.I) for key, value in MARKERS.items()}
START = re.compile(r"^PL_LOG_STORE:(?:set ram_header->sig| check once,)")
SAVE_FIELDS = re.compile(r"offset (0x[0-9a-f]+), size (0x[0-9a-f]+)", re.I)
EARLY_FIELDS = re.compile(r"flag (0x[0-9a-f]+), reboot count (0x[0-9a-f]+)", re.I)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def analyze_bytes(data):
    raw_lines = data.splitlines(keepends=True)
    lines = [line.decode("ascii", errors="replace").rstrip("\r\n").lstrip("\0")
             for line in raw_lines]
    offsets = [0]
    for line in raw_lines:
        offsets.append(offsets[-1] + len(line))

    hits = {key: [] for key in PATTERNS}
    for index, line in enumerate(lines):
        for key, pattern in PATTERNS.items():
            if pattern.search(line):
                hits[key].append({"line": index + 1, "text_offset": offsets[index],
                                  "text": line})

    starts = [index for index, line in enumerate(lines) if START.search(line)]
    if lines and (not starts or starts[0] != 0):
        starts.insert(0, 0)
    fragments = []
    for index, begin in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else len(lines)
        selected = {key: [hit for hit in values if begin < hit["line"] <= end]
                    for key, values in hits.items()}
        prefix_end = selected["sram_save"][0]["line"] if selected["sram_save"] else None
        fragment = {
            "fragment": index + 1, "line_start": begin + 1, "line_end": end,
            "text_offset_start": offsets[begin], "text_offset_end": offsets[end],
            "sha256": sha256(data[offsets[begin]:offsets[end]]),
            "marker_counts": {key: len(value) for key, value in selected.items()},
            "early_prefix_end_line": prefix_end,
            "early_prefix_sha256": (sha256(data[offsets[begin]:offsets[prefix_end]])
                                    if prefix_end is not None else None),
            "early_prefix_line_count": prefix_end - begin if prefix_end is not None else 0,
            "continues_after_early_save": prefix_end is not None and end > prefix_end,
            "save_records": [], "early_save_records": [],
            "execution_stop_inferred": False,
        }
        for hit in selected["sram_save"]:
            match = SAVE_FIELDS.search(hit["text"])
            if match:
                fragment["save_records"].append({
                    "line": hit["line"], "reported_offset": match[1],
                    "reported_size": match[2],
                })
        for hit in selected["early_save"]:
            match = EARLY_FIELDS.search(hit["text"])
            if match:
                fragment["early_save_records"].append({
                    "line": hit["line"], "flag": match[1], "reboot_count": match[2],
                })
        fragments.append(fragment)

    prefixes = {}
    for fragment in fragments:
        digest = fragment["early_prefix_sha256"]
        if digest is not None:
            prefixes.setdefault(digest, []).append(fragment)
    duplicates = [
        {"sha256": digest, "fragments": [item["fragment"] for item in group],
         "line_count": group[0]["early_prefix_line_count"],
         "meaning": "Byte-identical retained prefix, not independent boot evidence."}
        for digest, group in prefixes.items() if len(group) > 1
    ]

    flash_windows = []
    flash_hits = sorted(hits["flash_boot_a"] + hits["flash_boot_b"], key=lambda hit: hit["line"])
    for flash in flash_hits:
        owner = next(item for item in fragments
                     if item["line_start"] <= flash["line"] <= item["line_end"])
        reboots = [hit for hit in hits["reboot_request"]
                   if flash["line"] < hit["line"] <= owner["line_end"]]
        if not reboots:
            continue
        reboot = reboots[0]
        later = [item for item in fragments if item["line_start"] > reboot["line"]]
        following = later[0] if later else None
        flash_windows.append({
            "flash_line": flash["line"], "reboot_line": reboot["line"],
            "following_fragment": following["fragment"] if following else None,
            "adjacent_text_start_line": reboot["line"] + 1,
            "adjacent_text_end_line": (following["early_prefix_end_line"]
                                       or following["line_end"]) if following else None,
            "candidate_identity": "Not encoded in a flash command or download size.",
            "chronology": "Physical order in this strings file only; not a validated boot timeline.",
        })

    return {
        "schema_version": 1, "input_size": len(data), "input_sha256": sha256(data),
        "line_count": len(lines), "nul_byte_count": data.count(b"\0"),
        "offsets_scope": "Byte offsets in the supplied text, NOT in the original expdb partition.",
        "marker_counts": {key: len(value) for key, value in hits.items()},
        "marker_occurrences": hits, "fragments": fragments,
        "duplicate_early_prefixes": duplicates, "flash_adjacent_text": flash_windows,
        "limitations": [
            "strings removes binary log headers, offsets and compressed AEE payloads.",
            "Fragment boundaries are text signatures, not authenticated boot/session boundaries.",
            "early_save_pllog is a store operation; its neighboring fragment need not be a new boot.",
            "A missing LK/UEFI marker does not identify the execution stop.",
            "RAM_CONSOLE reset status describes retained reset state, not a fault at that print.",
            "#T#WDT_INIT is a timing label, not a watchdog-reset cause enumeration.",
            "Raw LASTPC fields are not decoded or symbolized by this tool.",
            "AEE text names alone do not validate an AEE header or bind it to this attempt.",
        ],
    }


def write_new(path, data):
    with path.open("xb") as stream:
        stream.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path,
                        help="New output directory; all existing paths are refused")
    args = parser.parse_args()
    source = args.input.resolve(strict=True)
    output = args.output.absolute()
    if output.exists() or output.is_symlink():
        parser.error("output must be a new directory")
    if source.stat().st_size > 32 * 1024 * 1024:
        parser.error("expected a bounded strings capture, not a raw partition")
    data = source.read_bytes()
    result = analyze_bytes(data)
    result["input_path"] = str(source)
    output.mkdir(parents=True, exist_ok=False)
    write_new(output / "input.strings", data)
    write_new(output / "fragments.json", (json.dumps(result, indent=2) + "\n").encode("ascii"))

    raw_lines = data.splitlines(keepends=True)
    for index, window in enumerate(result["flash_adjacent_text"], 1):
        if window["adjacent_text_end_line"] is not None:
            first = window["adjacent_text_start_line"] - 1
            last = window["adjacent_text_end_line"]
            write_new(output / f"flash-{index:02d}-adjacent-text.txt", b"".join(raw_lines[first:last]))
    summary = {key: result[key] for key in (
        "input_sha256", "line_count", "marker_counts", "duplicate_early_prefixes",
        "flash_adjacent_text",
    )}
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
