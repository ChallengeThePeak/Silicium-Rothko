#!/usr/bin/env python3
"""Build an already prepared, independent Rothko UEFI source snapshot."""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path


def hash_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument("--build-id", default="rothko-evidence-20261031")
    parser.add_argument("--require-clean-source", action="store_true")
    args = parser.parse_args()
    workspace = args.workspace.resolve(strict=True)
    output = args.output.absolute()
    if output.exists() or output.is_symlink():
        parser.error("output directory must be new")
    fd = workspace / "Build/rothkoPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd"
    if (workspace / "Build/rothkoPkg").exists():
        parser.error("workspace must have a fresh platform build directory")
    source_commit = subprocess.check_output(
        ["git", "-C", str(workspace), "rev-parse", "HEAD"], text=True,
    ).strip()
    source_status = subprocess.check_output(
        ["git", "-C", str(workspace), "status", "--porcelain", "--untracked-files=no"],
        text=True,
    )
    if args.require_clean_source and source_status:
        parser.error("tracked source changes must be checkpointed before building")
    output.mkdir(parents=True)
    conf = output / "conf"
    conf.mkdir()
    tools = workspace / "Mu_Basecore/BaseTools"
    for name in ("target", "tools_def", "build_rule"):
        shutil.copyfile(tools / f"Conf/{name}.template", conf / f"{name}.txt")

    env = os.environ.copy()
    env.update({
        "WORKSPACE": str(workspace),
        "EDK_TOOLS_PATH": str(tools),
        "CONF_PATH": str(conf),
        "PYTHON_COMMAND": "python3",
        "CLANG_BIN": str(Path(shutil.which("clang")).parent) + "/",
        "PACKAGES_PATH": ":".join(str(workspace / path) for path in (
            ".", "Platforms/Xiaomi", "Common/Mu", "Common/Mu_OEM_Sample",
            "Mu_Basecore", "Silicon/MediaTek", "Silicon/Silicium",
        )),
    })
    env["PATH"] = ":".join((
        str(tools / "BinWrappers/PosixLike"),
        str(tools / "Source/C/bin"),
        env["PATH"],
    ))
    command = [
        "build", "-p", "rothkoPkg/rothko.dsc", "-a", "AARCH64",
        "-b", "DEBUG", "-t", "CLANGPDB", "-n", str(max(1, args.jobs)),
        "-D", "FD_BASE=0x42000000", "-D", "FD_SIZE=0x200000",
        "-D", "FD_BLOCKS=0x200", "-D", "DEVICE_MODEL=0",
        "-D", "ENABLE_SECUREBOOT=0", "-D", "MEMORY_PROTECTION=FALSE",
        "-D", "SHIP_MODE=FALSE", "-D", f"BUILDID_STRING={args.build_id}",
        "-y", str(output / "edk-report.txt"),
        "-Y", "PCD", "-Y", "LIBRARY",
    ]
    with (output / "build.log").open("x") as log:
        result = subprocess.run(
            command, cwd=workspace, env=env, stdout=log,
            stderr=subprocess.STDOUT, check=False,
        )
    record = {
        "workspace": str(workspace),
        "command": command,
        "returncode": result.returncode,
        "source_commit": source_commit,
        "source_tracked_status_before": source_status,
        "build_script_sha256": hash_file(Path(__file__)),
        "clang": subprocess.check_output(["clang", "--version"], text=True),
        "firmware": str(fd),
        "firmware_size": fd.stat().st_size if fd.is_file() else None,
        "firmware_sha256": hash_file(fd) if fd.is_file() else None,
        "build_log_sha256": hash_file(output / "build.log"),
        "device_operations": [],
    }
    with (output / "result.json").open("x") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")
    print(json.dumps(record, indent=2))
    return result.returncode if result.returncode else (0 if fd.is_file() else 1)


if __name__ == "__main__":
    raise SystemExit(main())
