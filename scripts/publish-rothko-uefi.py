#!/usr/bin/env python3
"""Publish only a new boot whose actual FV contains the required driver code."""

import argparse
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys


def digest(data):
    return hashlib.sha256(data).hexdigest()


def hash_file(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def write_new(path, data):
    with path.open("xb") as stream:
        stream.write(data)


def git(workspace, *args):
    return subprocess.check_output(["git", "-C", str(workspace), *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--records", required=True, type=Path)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()
    require(sys.platform == "linux", "Run artifact publication in WSL")
    project = Path(__file__).resolve().parents[1]
    workspace = args.workspace.resolve(strict=True)
    records = args.records.resolve(strict=True)
    output = args.output.absolute()
    manifest = args.manifest.absolute()
    for path in (output, manifest):
        require(not path.exists() and not path.is_symlink(), f"Refusing existing output: {path}")

    build_path = records / "build-01/result.json"
    build = json.loads(build_path.read_text())
    fix = json.loads((records / "source-fix.json").read_text())
    before_path = records / "source-before.json"
    before = json.loads(before_path.read_text())
    source_commit = git(workspace, "rev-parse", "HEAD")
    require(build["returncode"] == 0, "Firmware build failed")
    require(source_commit == build["source_commit"] == fix["source_commit"], "Source/build commit mismatch")
    require(not git(workspace, "status", "--porcelain", "--untracked-files=no"), "Tracked source changed")
    require(build["source_tracked_status_before"] == "", "Build source was not checkpointed")
    require(hash_file(project / "scripts/build-rothko-evidence.py") == build["build_script_sha256"],
            "Build script identity changed")
    require(hash_file(records / "build-01/build.log") == build["build_log_sha256"], "Build log identity changed")
    require(git(workspace, "diff", "--name-only", fix["baseline_commit"], source_commit).splitlines()
            == [fix["changed_file"]], "Unexpected additional source changes")
    require(hash_file(workspace / fix["changed_file"]) == fix["after_sha256"], "FDF include differs from recorded fix")
    before_hashes = {entry["path"]: entry.get("sha256") for entry in before["entries"]}
    unchanged = [
        "Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc",
        "Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c",
        "Platforms/Xiaomi/rothkoPkg/Drivers/RothkoWatchdogDxe/RothkoWatchdogDxe.c",
    ]
    for relative in unchanged:
        require(hash_file(workspace / relative) == before_hashes[relative], f"Unexpected driver/order edit: {relative}")

    image = args.image.read_bytes()
    require(len(image) == 0x4000000 and image[:8] == b"ANDROID!", "Expected a 64 MiB Android boot image")
    require(struct.unpack_from("<I", image, 40)[0] == 4, "Expected Android boot v4")
    kernel_size, ramdisk_size = struct.unpack_from("<II", image, 8)
    require(0 < kernel_size < 0x200000 and ramdisk_size == 0, "Unexpected payload sizes")
    kernel = gzip.decompress(image[4096:4096 + kernel_size])
    shim = (records / "package-01/shim.bin").read_bytes()
    require(kernel.startswith(shim), "Packaged shim does not match the assembled input")
    firmware = kernel[len(shim):]
    require(len(firmware) == 0x200000 and digest(firmware) == build["firmware_sha256"],
            "Packaged firmware differs from the actual fresh build")
    require(firmware == (workspace / "Build/rothkoPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd").read_bytes(),
            "Current FD differs from packaged firmware")
    require(shim[56:60] == b"ARM\x64" and struct.unpack_from("<QQ", shim, 8) == (0x42000000, len(kernel)),
            "Invalid BootShim placement/header")
    require(digest(shim) == "188316d05cfd4fee0491031eff012e1207a705471dd19462f58fb0b2c30b1e40",
            "Inherited stage-coded BootShim changed")

    # Check the FD extracted from the final boot, not a neighboring build file.
    checker_path = project / "scripts/audit-rothko-fv.py"
    spec = importlib.util.spec_from_file_location("rothko_fv_audit", checker_path)
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    audit_dir = records / "published-fv-audit-01"
    fv = checker.audit_firmware(firmware, workspace / "Build/rothkoPkg/DEBUG_CLANGPDB/AARCH64", audit_dir)
    require(fv["verified"] and fv["traversal_complete"], f"Actual boot FV is incomplete: {fv['problems']}")
    for member in fv["required_modules"]:
        require(member["executable_ffs_count"] == 1 and member["apriori_reference"], "Required driver/order missing")
        require(member["flat_comparison"]["byte_equal"], "Packaged executable differs from linked code")
    fv["checker_sha256"] = hash_file(checker_path)
    write_new(audit_dir / "fv-audit.json", (json.dumps(fv, indent=2) + "\n").encode("ascii"))

    sys.path.insert(0, str(project / "src/uefi-rothko-evidence-20261031/scripts"))
    from avb_footer import verify
    avb = verify(image, "boot")
    require(avb["digest_ok"], "AVB footer digest mismatch")
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    require(shutil.disk_usage(output.parent).free > len(image) + 64 * 1024 * 1024, "Insufficient publication reserve")
    write_new(output, image)
    require(hash_file(output) == digest(image), "Published image differs")
    result = {
        "date": "2026-11-01", "status": "actual_boot_fv_membership_verified", "device_tested": False,
        "device_operations": [], "source_workspace": str(workspace), "source_commit": source_commit,
        "source_baseline_commit": fix["baseline_commit"], "source_change": fix["changed_file"],
        "source_before_manifest": str(before_path), "source_before_manifest_sha256": hash_file(before_path),
        "build_result": str(build_path), "build_result_sha256": hash_file(build_path),
        "build_script_sha256": build["build_script_sha256"], "publication_script_sha256": hash_file(Path(__file__)),
        "firmware_sha256": digest(firmware), "firmware_size": len(firmware),
        "image": str(output), "image_sha256": digest(image), "image_size": len(image),
        "kernel_size": kernel_size, "kernel_size_hex": hex(kernel_size), "ramdisk_size": ramdisk_size,
        "shim_sha256": digest(shim), "avbf_digest_verified": True,
        "fv_audit": str(audit_dir / "fv-audit.json"), "fv_checker_sha256": hash_file(checker_path),
        "fv_traversal_complete": True, "dangling_apriori_references": fv["dangling_apriori_references"],
        "required_modules": fv["required_modules"],
        "limitations": ["Static driver presence and byte identity are verified, not hardware execution.",
                        "Old expdb proves candidate LK loading but supplies no valid BootShim/SEC/DXE PC.",
                        "This candidate fixes a definite FDF omission without asserting it is the only hardware blocker."]}
    write_new(manifest, (json.dumps(result, indent=2) + "\n").encode("ascii"))
    print(json.dumps({key: result[key] for key in ("status", "source_commit", "firmware_sha256", "image",
                     "image_sha256", "kernel_size_hex", "dangling_apriori_references", "device_tested")}, indent=2))


if __name__ == "__main__":
    main()
