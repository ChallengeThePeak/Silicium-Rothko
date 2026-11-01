#!/usr/bin/env python3
"""Bind a fresh keepalive build, actual-source tests, and its new boot image."""

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys


DRIVER = "Platforms/Xiaomi/rothkoPkg/Drivers/RothkoWatchdogDxe/RothkoWatchdogDxe.c"
FV = "Build/rothkoPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd"
MODULE = "Build/rothkoPkg/DEBUG_CLANGPDB/AARCH64/RothkoWatchdogDxe.efi"
MAP = ("Build/rothkoPkg/DEBUG_CLANGPDB/AARCH64/rothkoPkg/Drivers/"
       "RothkoWatchdogDxe/RothkoWatchdogDxe/OUTPUT/RothkoWatchdogDxe.map")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def hash_file(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def write_new(path, content):
    with path.open("xb") as stream:
        stream.write(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--records", required=True, type=Path)
    parser.add_argument("--baseline-commit", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--publish", required=True, type=Path)
    args = parser.parse_args()
    require(sys.platform == "linux", "Run this packaging audit in WSL")
    project = Path(__file__).resolve().parents[1]
    workspace = args.workspace.resolve(strict=True)
    records = args.records.resolve(strict=True)
    output = args.output.absolute()
    publish = args.publish.absolute()
    require(not output.exists() and not output.is_symlink(), "Audit output already exists")
    require(not publish.exists() and not publish.is_symlink(), "Published image already exists")

    build_path = records / "build-01/result.json"
    build = json.loads(build_path.read_text())
    source_manifest = records / "source-before.json"
    source_inventory = json.loads(source_manifest.read_text())
    fixed_test_path = records / "watchdog-host-fixed-gcc-01/result.json"
    old_test_path = records / "watchdog-host-old-regression-gcc-02/result.json"
    fixed_test = json.loads(fixed_test_path.read_text())
    old_test = json.loads(old_test_path.read_text())
    source_head = command("git", "-C", str(workspace), "rev-parse", "HEAD")
    baseline = command("git", "-C", str(workspace), "rev-parse", args.baseline_commit)
    source_status = command("git", "-C", str(workspace), "status", "--porcelain", "--untracked-files=no")
    require(not source_status, "Tracked source changed after build")
    require(build["returncode"] == 0 and build["source_commit"] == source_head,
            "Build did not succeed at the current source checkpoint")
    require(build["workspace"] == str(workspace), "Build names another workspace")
    require(build["source_tracked_status_before"] == "", "Build started from dirty tracked source")
    require(hash_file(project / "scripts/build-rothko-evidence.py") == build["build_script_sha256"],
            "Build script changed after invocation")
    require(hash_file(records / "build-01/build.log") == build["build_log_sha256"],
            "Build log differs from its result manifest")

    before = subprocess.check_output(["git", "-C", str(workspace), "show", f"{baseline}:{DRIVER}"])
    after = (workspace / DRIVER).read_bytes()
    expected = before.replace(b"STATIC UINT32 mDiagnosticTicks;\n", b"").replace(
        b"if (mActive && (++mDiagnosticTicks < 600))", b"if (mActive)")
    require(before != expected and after == expected, "Driver delta exceeds the intended cutoff removal")
    changed = command("git", "-C", str(workspace), "diff", "--name-only", baseline, source_head).splitlines()
    require(changed == [DRIVER], "Unexpected source changes in candidate checkpoint")
    source_patch = command("git", "-C", str(workspace), "diff", baseline, source_head, "--", DRIVER)
    require(fixed_test["passed"] and fixed_test["source_unchanged"], "Fixed actual-source host test failed")
    require(fixed_test["source_sha256"] == digest(after), "Host test used another driver source")
    require(old_test["source_sha256"] == digest(before), "Negative control used another baseline")
    require(old_test["compile_returncode"] == 0 and old_test["source_unchanged"],
            "Negative control is not a valid unchanged-source run")
    require([case["name"] for case in old_test["tests"] if case["returncode"] != 0] == ["continued_feeding"],
            "Negative control did not isolate the watchdog cutoff")
    require(len(fixed_test["tests"]) == 7 and all(case["returncode"] == 0 for case in fixed_test["tests"]),
            "Incomplete fixed host regression")
    test_hash = hash_file(project / "scripts/test-rothko-watchdog-host.py")
    require(old_test["test_script_sha256"] == fixed_test["test_script_sha256"] == test_hash,
            "Negative/fixed tests used different test implementations")

    firmware = (workspace / FV).read_bytes()
    shim = (records / "package-01/shim.bin").read_bytes()
    image_path = records / "boot-rothko-uefi-keepalive-20261101-avbf.img"
    image = image_path.read_bytes()
    require(len(firmware) == 0x200000 and digest(firmware) == build["firmware_sha256"],
            "Fresh FD does not match its build result")
    require(image[:8] == b"ANDROID!" and struct.unpack_from("<I", image, 40)[0] == 4,
            "Expected Android boot v4")
    kernel_size, ramdisk_size = struct.unpack_from("<II", image, 8)
    require(ramdisk_size == 0 and 0 < kernel_size < 0x200000, "Unexpected payload sizes")
    unpacked = gzip.decompress(image[4096:4096 + kernel_size])
    require(unpacked == shim + firmware, "Packaged bytes do not match the fresh shim and FD")
    require(shim[56:60] == b"ARM\x64" and struct.unpack_from("<QQ", shim, 8) ==
            (0x42000000, len(unpacked)), "BootShim header placement mismatch")
    require(digest(shim) == "188316d05cfd4fee0491031eff012e1207a705471dd19462f58fb0b2c30b1e40",
            "The inherited stage-coded BootShim changed")
    sys.path.insert(0, str(project / "src/uefi-rothko-evidence-20261031/scripts"))
    from avb_footer import verify
    avb = verify(image, "boot")
    require(avb["digest_ok"] and len(image) == 0x4000000, "AVBf digest or partition size mismatch")

    symbols = {}
    for line in (workspace / MAP).read_text().splitlines():
        match = re.match(r"^([0-9a-fA-F]+)\s+[0-9a-fA-F]+\s+\d+\s+(KickWatchdog|StopWatchdog)$", line)
        if match:
            symbols[match[2]] = int(match[1], 16)
    require(symbols.keys() >= {"KickWatchdog", "StopWatchdog"}, "Watchdog map symbols are missing")
    disassembly = command("llvm-objdump", "-d", "--no-show-raw-insn",
                          f"--start-address={hex(symbols['KickWatchdog'])}",
                          f"--stop-address={hex(symbols['StopWatchdog'])}", str(workspace / MODULE))
    require("mDiagnosticTicks" not in (workspace / MAP).read_text(), "Diagnostic counter remains linked")
    old_image = project / "work/evidence-20261031/boot-rothko-uefi-confirmed-20261101-avbf.img"
    old_image_hash = hash_file(old_image)
    require(digest(image) != old_image_hash, "Refusing to publish a renamed old image")

    # Keep D: usage bounded: one final image, no copied build tree or intermediates.
    publish.parent.mkdir(parents=True, exist_ok=True)
    require(shutil.disk_usage(publish.parent).free > len(image) + 64 * 1024 * 1024,
            "Insufficient space to publish while preserving a 64 MiB reserve")
    write_new(publish, image)
    require(hash_file(publish) == digest(image), "Published copy differs from the audited image")
    result = {
        "date": "2026-11-01", "status": "fresh_offline_build_and_regression_passed",
        "device_tested": False, "device_operations": [],
        "source": {"workspace": str(workspace), "baseline_commit": baseline, "commit": source_head,
                   "changed_files": changed, "driver_sha256": digest(after), "patch": source_patch,
                   "before_inventory": str(source_manifest),
                   "before_inventory_file_sha256": hash_file(source_manifest),
                   "before_inventory_sha256": source_inventory["inventory_sha256"],
                   "before_files_and_links": source_inventory["files_and_links"]},
        "build": {"result_path": str(build_path), "result_sha256": hash_file(build_path),
                  "command": build["command"], "returncode": build["returncode"],
                  "build_script_sha256": build["build_script_sha256"],
                  "firmware_sha256": digest(firmware), "firmware_size": len(firmware),
                  "module_sha256": hash_file(workspace / MODULE),
                  "kick_watchdog_rva": hex(symbols["KickWatchdog"]), "kick_disassembly": disassembly,
                  "warnings": [line for line in (records / "build-01/build.log").read_text().splitlines()
                               if "warning:" in line.lower()]},
        "tests": {"fixed_result": str(fixed_test_path), "fixed_sha256": hash_file(fixed_test_path),
                  "fixed_passed": True, "fixed_cases": len(fixed_test["tests"]),
                  "baseline_result": str(old_test_path), "baseline_sha256": hash_file(old_test_path),
                  "baseline_failure": "continued_feeding", "test_script_sha256": test_hash},
        "package": {"image": str(publish), "sha256": digest(image), "size": len(image),
                    "header_version": 4, "kernel_size": kernel_size, "ramdisk_size": ramdisk_size,
                    "shim_size": len(shim), "shim_sha256": digest(shim),
                    "avbf_digest_verified": avb["digest_ok"],
                    "previous_image_sha256": old_image_hash},
        "limitations": ["No device boot, flash, reset, or live hardware test was performed.",
                        "Host tests mock RothkoStage; physical timing and IRQ delivery remain untested.",
                        "The callback cutoff fix does not localize the user's early failed boot.",
                        "A headerless strings capture cannot reconstruct the missing AEE runtime record."]}
    output.parent.mkdir(parents=True, exist_ok=True)
    write_new(output, (json.dumps(result, indent=2) + "\n").encode("ascii"))
    print(json.dumps({"manifest": str(output), "image": str(publish),
                      "sha256": result["package"]["sha256"],
                      "firmware_sha256": result["build"]["firmware_sha256"],
                      "source_commit": source_head, "host_tests": "7/7", "device_tested": False}, indent=2))


if __name__ == "__main__":
    main()
