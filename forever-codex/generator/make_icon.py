#!/usr/bin/env python3
"""Draws the Forever Codex minimap icon (a round gold-ringed badge with a "C" on an open book) as a 64x64 32-bit TGA.

Pure Python, no dependencies, deterministic. The art is original (shapes drawn here); nothing is copied from another addon or the game.
Usage: python3 generator/make_icon.py [--preview out.png]   ->  ForeverCodex/Media/CodexIcon.tga
The TGA is uncompressed 32-bit BGRA, top-left origin, 64x64 (a power of two, as WoW textures must be).
"""
import argparse
import math
import struct
import zlib
from pathlib import Path

N, SS = 64, 4                      # output size, supersampling per axis
OUT = Path(__file__).resolve().parent.parent / "ForeverCodex" / "Media" / "CodexIcon.tga"


def inside_convex(poly, x, y):
    s = 0
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        c = (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)
        if c == 0:
            continue
        if s == 0:
            s = 1 if c > 0 else -1
        elif (c > 0) != (s > 0):
            return False
    return True


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


COVER = [(8, 22), (32, 28), (56, 22), (56, 49), (32, 55), (8, 49)]
LEFT = [(11, 23), (31, 28.5), (31, 51), (11, 45.5)]
RIGHT = [(33, 28.5), (53, 23), (53, 45.5), (33, 51)]


def shade(x, y):
    """RGBA (0..1) of the art at a point in 0..64 coordinates."""
    dx, dy = x - 32, y - 32
    r = math.hypot(dx, dy)
    if r > 31.6:
        return (0, 0, 0, 0)
    # the C: an arc opening to the right, drawn over the pages
    cx, cy = 32, 38.5
    rr = math.hypot(x - cx, y - cy)
    ang = math.degrees(math.atan2(y - cy, x - cx))
    if 6.0 <= rr <= 10.8 and abs(ang) > 42:
        return (0.42, 0.10, 0.12, 1)
    if inside_convex(LEFT, x, y) or inside_convex(RIGHT, x, y):
        if abs(x - 32) < 1.0 and rr > 11.0:                      # the gutter (not through the C)
            return (0.62, 0.52, 0.34, 1)
        shade_t = (y - 23) / 30.0
        base = lerp((0.98, 0.93, 0.78), (0.90, 0.82, 0.62), max(0, min(1, shade_t)))
        # a little shadow toward the spine
        d = abs(x - 32)
        if d < 5:
            base = lerp(base, (0.72, 0.62, 0.42), (5 - d) / 5 * 0.6)
        return base + (1,)
    if inside_convex(COVER, x, y):
        return (0.36, 0.17, 0.10, 1)
    # the badge: gold ring, dark edge, deep blue-green field
    if r >= 28.4:
        t = (y - 0) / 64.0
        return lerp((1.0, 0.86, 0.38), (0.78, 0.55, 0.14), t) + (1,)
    if r >= 27.0:
        return (0.20, 0.13, 0.05, 1)
    return lerp((0.14, 0.24, 0.30), (0.05, 0.09, 0.14), r / 27.0) + (1,)


def render():
    px = []
    for j in range(N):
        row = []
        for i in range(N):
            a = r = g = b = 0.0
            for sj in range(SS):
                for si in range(SS):
                    cr, cg, cb, ca = shade(i + (si + 0.5) / SS, j + (sj + 0.5) / SS)
                    a += ca
                    r += cr * ca
                    g += cg * ca
                    b += cb * ca
            n = SS * SS
            if a > 0:
                row.append((r / a, g / a, b / a, a / n))
            else:
                row.append((0, 0, 0, 0))
        px.append(row)
    return px


def to_bytes(v):
    return max(0, min(255, int(round(v * 255))))


def write_tga(px, path):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 0x28)      # uncompressed true-colour, 32 bpp, top-left origin, 8 alpha bits
    body = bytearray()
    for row in px:
        for r, g, b, a in row:
            body += bytes((to_bytes(b), to_bytes(g), to_bytes(r), to_bytes(a)))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + bytes(body))


def write_png(px, path, scale=4):
    raw = bytearray()
    for row in px:
        line = bytearray()
        for r, g, b, a in row:
            line += bytes((to_bytes(r), to_bytes(g), to_bytes(b), to_bytes(a))) * scale
        for _ in range(scale):
            raw += b"\x00" + line

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N * scale, N * scale, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="also write a PNG preview here")
    args = ap.parse_args()
    pixels = render()
    write_tga(pixels, OUT)
    if args.preview:
        write_png(pixels, args.preview)
    print(OUT, OUT.stat().st_size, "bytes")
