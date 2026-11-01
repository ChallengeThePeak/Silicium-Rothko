#!/usr/bin/env python3
"""Fetch avbtool (a single self-contained Python script) for building vbmeta.

Tries the AOSP gitiles endpoint and a GitHub mirror, through the local proxy
when one is reachable. Writes to the tools directory next to this script.
"""
import base64
import pathlib
import sys
import urllib.request

OUT = pathlib.Path("/home/ubuntu/rothko/tools/avbtool")
OUT.parent.mkdir(parents=True, exist_ok=True)

PROXY = "http://172.30.32.1:7897"   # Windows host as seen from WSL (NAT gateway)

SOURCES = [
    ("gitiles", "https://android.googlesource.com/platform/external/avb/+/refs/heads/main/avbtool?format=TEXT", True),
    ("github-lineage", "https://raw.githubusercontent.com/LineageOS/android_external_avb/lineage-21.0/avbtool", False),
    ("github-ghproxy", "https://gh-proxy.com/https://raw.githubusercontent.com/LineageOS/android_external_avb/lineage-21.0/avbtool", False),
    ("github-aosp", "https://raw.githubusercontent.com/aosp-mirror/platform_external_avb/master/avbtool", False),
]


def fetch(url: str, via_proxy: bool) -> bytes:
    handlers = []
    if via_proxy:
        handlers.append(urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))
    opener = urllib.request.build_opener(*handlers)
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    with opener.open(req, timeout=60) as r:
        return r.read()


for name, url, b64 in SOURCES:
    for proxy in (True, False):
        try:
            data = fetch(url, proxy)
        except Exception as exc:  # noqa: BLE001 - report and try the next source
            print(f"  {name} proxy={proxy}: {type(exc).__name__}: {exc}")
            continue
        if b64:
            data = base64.b64decode(data)
        if not data.startswith(b"#!"):
            print(f"  {name} proxy={proxy}: not a script ({data[:40]!r})")
            continue
        OUT.write_bytes(data)
        OUT.chmod(0o755)
        print(f"OK {name} proxy={proxy}: {len(data)} B -> {OUT}")
        sys.exit(0)

print("all sources failed", file=sys.stderr)
sys.exit(1)
