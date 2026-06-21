#!/usr/bin/env python3
"""Generates the launcher icon assets with no third-party deps (stdlib only).

Draws a white "play" triangle. Two outputs:
  assets/icon/icon.png        1024x1024 red background + white triangle (legacy)
  assets/icon/foreground.png  1024x1024 transparent + white triangle (adaptive)
"""
import os
import struct
import zlib

SIZE = 1024
RED = (0xFF, 0x00, 0x00, 0xFF)
WHITE = (0xFF, 0xFF, 0xFF, 0xFF)
CLEAR = (0, 0, 0, 0)

# Right-pointing play triangle vertices (kept within the adaptive safe zone).
P1 = (390.0, 300.0)
P2 = (390.0, 724.0)
P3 = (734.0, 512.0)


def _sign(ax, ay, bx, by, cx, cy):
    return (ax - cx) * (by - cy) - (bx - cx) * (ay - cy)


def in_triangle(x, y):
    d1 = _sign(x, y, *P1, *P2)
    d2 = _sign(x, y, *P2, *P3)
    d3 = _sign(x, y, *P3, *P1)
    has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (has_neg and has_pos)


def build(bg):
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)  # filter type 0 for the scanline
        for x in range(SIZE):
            px = WHITE if in_triangle(x + 0.5, y + 0.5) else bg
            rows.extend(px)
    return bytes(rows)


def chunk(tag, data):
    out = struct.pack(">I", len(data)) + tag + data
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return out + struct.pack(">I", crc)


def write_png(path, bg):
    raw = build(bg)
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print("wrote", path)


if __name__ == "__main__":
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    write_png(os.path.join(here, "assets/icon/icon.png"), RED)
    write_png(os.path.join(here, "assets/icon/foreground.png"), CLEAR)
