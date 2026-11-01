#!/usr/bin/env python3
"""解析 pmsg 环形缓冲并把有效文本落成 .txt"""
import struct
import sys
from pathlib import Path

src = Path(r"D:\漏洞\UNIXNU\适配K70U\logs\pmsg-lo4g.bin")
dst = src.with_suffix(".txt")
raw = src.read_bytes()
print(f"file bytes = {len(raw)}")

sig, start, size = struct.unpack_from("<Iii", raw, 0)
print(f"header: sig=0x{sig:08x} start={start} size={size}")

if sig == 0x43474244:  # 'DBGC'
    data = raw[12:]
    cap = len(data)
    if size < 0 or size > cap or start < 0 or start >= cap:
        text = data
        print("header不合法，按裸数据输出")
    else:
        # 环形：从 start 开始读 size 字节
        if start + size <= cap:
            text = data[start:start + size]
        else:
            text = data[start:] + data[:(start + size) % cap]
        print(f"ring: capacity={cap} start={start} size={size}")
else:
    text = raw
    print("无 DBGC 头，按裸数据输出")

dst.write_bytes(text)
print(f"written {dst} ({len(text)} bytes)")
print("---- 文本预览 ----")
sys.stdout.write(text.decode("utf-8", "replace"))
