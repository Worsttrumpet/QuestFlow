#!/usr/bin/env python3
"""Draws Forever Codex's own small pictures as 32-bit TGAs (pure Python, no dependencies, deterministic, all original shapes):

  (the logo itself, Media/QuestFlowLogo.tga, is made from the Quest Flow artwork by make_logo.py, not drawn here)
  Media/ArrowHead.tga     a bold arrowhead, white with a dark outline, pointing UP (the game rotates and tints it), 64 x 64
  Media/ArrowPointer.tga  an arrow with a shaft, same style, 64 x 64
  Media/IconBang.tga      "!" (a quest to pick up), white with a dark outline (tinted by the addon), 32 x 32
  Media/IconQuery.tga     "?" (a quest to hand in), 32 x 32
  Media/IconCheck.tga     a check mark, 32 x 32

Usage: python3 generator/make_art.py [--preview DIR]  
The TGAs are uncompressed 32-bit BGRA, top-left origin, sizes are powers of two.
"""
import argparse
import math
import struct
import zlib
from pathlib import Path

MEDIA = Path(__file__).resolve().parent.parent / "QuestFlow" / "Media"
SS = 4
DARK = (0.10, 0.07, 0.03)
WHITE = (1.0, 1.0, 1.0)


# ---------------------------------------------------------------- signed distance helpers (negative = inside)

def d_circle(x, y, cx, cy, r):
    return math.hypot(x - cx, y - cy) - r


def d_capsule(x, y, x0, y0, x1, y1, r):
    dx, dy = x1 - x0, y1 - y0
    t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy))) if (dx or dy) else 0.0
    return math.hypot(x - (x0 + t * dx), y - (y0 + t * dy)) - r


def d_polygon(x, y, pts):
    inside = False
    best = 1e9
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x < (x1 - x0) * (y - y0) / (y1 - y0) + x0:
            inside = not inside
        best = min(best, d_capsule(x, y, x0, y0, x1, y1, 0.0))
    return -best if inside else best


def polyline(points, r):
    segs = [(points[i], points[i + 1]) for i in range(len(points) - 1)]
    return lambda x, y: min(d_capsule(x, y, a[0], a[1], b[0], b[1], r) for a, b in segs)


def arc_points(cx, cy, rad, a0, a1, n=14):
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        out.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return out


def union(*fns):
    return lambda x, y: min(f(x, y) for f in fns)


# ---------------------------------------------------------------- rendering

def render(size, shape, outline, fill_color=WHITE, outline_color=DARK, fill_fn=None):
    """shape(x, y) -> signed distance in pixels (size coordinates). Fill where <= 0, a dark outline out to `outline` px."""
    px = []
    for j in range(size):
        row = []
        for i in range(size):
            r = g = b = a = 0.0
            for sj in range(SS):
                for si in range(SS):
                    x, y = i + (si + 0.5) / SS, j + (sj + 0.5) / SS
                    d = shape(x, y)
                    if d <= 0:
                        col, al = (fill_fn(x, y) if fill_fn else fill_color), 1.0
                    elif d <= outline:
                        col, al = outline_color, 1.0
                    else:
                        continue
                    r += col[0] * al; g += col[1] * al; b += col[2] * al; a += al
            if a > 0:
                row.append((r / a, g / a, b / a, a / (SS * SS)))
            else:
                row.append((0, 0, 0, 0))
        px.append(row)
    return px


def write_tga(px, path):
    n = len(px)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, n, n, 32, 0x28)
    body = bytearray()
    for row in px:
        for r, g, b, a in row:
            body += bytes(max(0, min(255, int(round(v * 255)))) for v in (b, g, r, a))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + bytes(body))


def write_png(px, path, scale=4):
    n = len(px)
    raw = bytearray()
    for row in px:
        line = bytearray()
        for r, g, b, a in row:
            line += bytes(max(0, min(255, int(round(v * 255)))) for v in (r, g, b, a)) * scale
        for _ in range(scale):
            raw += b"\x00" + line

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", n * scale, n * scale, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


# ---------------------------------------------------------------- the pictures

def logo():
    """The C on an open book (the 0.2.8 badge art without the ring), 64 x 64."""
    def inside_convex(poly, x, y):
        s = 0
        for i in range(len(poly)):
            x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % len(poly)]
            c = (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)
            if c == 0:
                continue
            if s == 0:
                s = 1 if c > 0 else -1
            elif (c > 0) != (s > 0):
                return False
        return True
    cover = [(5, 18), (32, 25), (59, 18), (59, 50), (32, 57), (5, 50)]
    left = [(8, 19.5), (31, 26), (31, 53), (8, 46.5)]
    right = [(33, 26), (56, 19.5), (56, 46.5), (33, 53)]

    def lerp(a, b, t):
        return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

    px = []
    for j in range(64):
        row = []
        for i in range(64):
            r = g = b = a = 0.0
            for sj in range(SS):
                for si in range(SS):
                    x, y = i + (si + 0.5) / SS, j + (sj + 0.5) / SS
                    cx, cy = 32, 37.5
                    rr = math.hypot(x - cx, y - cy)
                    ang = math.degrees(math.atan2(y - cy, x - cx))
                    if 7.0 <= rr <= 12.4 and abs(ang) > 42:
                        col = (0.42, 0.10, 0.12)
                    elif inside_convex(left, x, y) or inside_convex(right, x, y):
                        if abs(x - 32) < 1.0 and rr > 13:
                            col = (0.62, 0.52, 0.34)
                        else:
                            base = lerp((0.98, 0.93, 0.78), (0.90, 0.82, 0.62), max(0, min(1, (y - 20) / 32.0)))
                            d = abs(x - 32)
                            col = lerp(base, (0.72, 0.62, 0.42), (5 - d) / 5 * 0.6) if d < 5 else base
                    elif inside_convex(cover, x, y):
                        col = (0.36, 0.17, 0.10)
                    else:
                        continue
                    r += col[0]; g += col[1]; b += col[2]; a += 1
            row.append((r / a, g / a, b / a, a / (SS * SS)) if a else (0, 0, 0, 0))
        px.append(row)
    return px


def arrow_head():
    return render(64, lambda x, y: d_polygon(x, y, [(32, 5), (56, 57), (32, 45), (8, 57)]), 2.6)


def arrow_pointer():
    return render(64, lambda x, y: d_polygon(x, y, [(32, 4), (55, 30), (41, 30), (41, 60), (23, 60), (23, 30), (9, 30)]), 2.6)


def icon_bang():
    # a tapered stroke (two capsules of different width) and a dot
    shape = union(lambda x, y: d_capsule(x, y, 16, 7, 16, 18, 4.2), lambda x, y: d_capsule(x, y, 16, 18, 16, 20.5, 2.6), lambda x, y: d_circle(x, y, 16, 26, 3.3))
    return render(32, shape, 2.0)


def icon_query():
    arc = polyline(arc_points(16, 11, 6.5, 200, 20 + 360 - 360 + 90, 16)[:0] or arc_points(16, 11, 6.5, 205, 450, 18), 2.6)   # round the top, opening to the lower left
    stem = polyline([(16 + 6.5 * math.cos(math.radians(450)), 11 + 6.5 * math.sin(math.radians(450))), (16, 19)], 2.6)
    dot = lambda x, y: d_circle(x, y, 16, 26.5, 3.0)
    return render(32, union(arc, stem, dot), 2.0)


def icon_check():
    return render(32, polyline([(6, 17), (13, 24), (26, 8)], 3.3), 2.0)


ART = {
    "ArrowHead.tga": arrow_head,
    "ArrowPointer.tga": arrow_pointer,
    "IconBang.tga": icon_bang,
    "IconQuery.tga": icon_query,
    "IconCheck.tga": icon_check,
}

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="also write PNG previews into this directory")
    args = ap.parse_args()
    for name, fn in ART.items():
        px = fn()
        write_tga(px, MEDIA / name)
        if args.preview:
            Path(args.preview).mkdir(parents=True, exist_ok=True)
            write_png(px, Path(args.preview) / (name[:-4] + ".png"), 4 if len(px) == 64 else 8)
        print(name, len(px), "px")
