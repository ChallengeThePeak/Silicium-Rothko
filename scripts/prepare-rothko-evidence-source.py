#!/usr/bin/env python3
"""Copy the existing WSL build source to a new, identified local snapshot."""

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def inventory(root):
    entries = []
    for path in sorted(root.rglob("*")):
        if ".git" in path.relative_to(root).parts:
            continue
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            entries.append({"path": relative, "symlink": str(path.readlink())})
        elif path.is_file():
            entries.append({
                "path": relative,
                "size": path.stat().st_size,
                "sha256": file_hash(path),
            })
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    source = args.source.resolve(strict=True)
    destination = args.destination.absolute()
    manifest = args.manifest.absolute()
    if not source.is_dir():
        parser.error("source must be an existing directory")
    if destination.exists() or destination.is_symlink():
        parser.error("destination must be a new path")
    if manifest.exists() or manifest.is_symlink():
        parser.error("manifest must be a new path")
    if source == destination or source in destination.parents:
        parser.error("destination must be outside the source")

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(
        source, destination, symlinks=True,
        ignore=shutil.ignore_patterns("Build", ".git", "__pycache__", "*.pyc"),
    )
    entries = inventory(destination)
    content_digest = hashlib.sha256(
        json.dumps(entries, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    record = {
        "source": str(source),
        "destination": str(destination),
        "origin": "local existing build source snapshot; not an upstream commit",
        "excluded": ["Build", ".git", "__pycache__", "*.pyc"],
        "files_and_links": len(entries),
        "inventory_sha256": content_digest,
        "entries": entries,
    }
    manifest.parent.mkdir(parents=True, exist_ok=True)
    with manifest.open("x") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")

    # Keep the port and shared boot code versioned without claiming vendor history.
    tracked = [
        "Platforms/Xiaomi/rothkoPkg",
        "Silicon/MediaTek/MT6989Pkg",
        "Silicon/Silicium/SiliciumPkg",
        "Mu_Basecore/ArmPkg/Drivers/ArmGicDxe",
        "Mu_Basecore/ArmPkg/Drivers/TimerDxe",
        "Mu_Basecore/MdeModulePkg/Core/Dxe/Mem/Pool.c",
        "Mu_Basecore/MdeModulePkg/Library/UefiBootManagerLib",
        "Mu_Basecore/MdeModulePkg/Universal/Console/GraphicsConsoleDxe",
        "Mu_Basecore/UefiCpuPkg/Library/CpuExceptionHandlerLib",
    ]
    subprocess.run(
        ["git", "init", "-b", "codex/k70u-uefi-evidence", str(destination)],
        check=True,
    )
    subprocess.run(["git", "-C", str(destination), "add", "--", *tracked], check=True)
    subprocess.run(
        ["git", "-C", str(destination), "-c", "user.name=Codex",
         "-c", "user.email=codex@local", "commit", "-m",
         "snapshot: preserve existing rothko boot source before evidence fixes"],
        check=True,
    )
    commit = subprocess.check_output(
        ["git", "-C", str(destination), "rev-parse", "HEAD"], text=True,
    ).strip()
    print(json.dumps({
        "manifest": str(manifest),
        "inventory_sha256": content_digest,
        "snapshot_commit": commit,
        "files_and_links": len(entries),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
