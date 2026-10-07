"""Renders docs/codex_icons_preview.png from the glyph grids in UI/CodexIcons.lua (no dependencies). Run from questflow."""
import re, zlib, struct
src = open('QuestFlow/UI/CodexIcons.lua').read()
glyphs = {}
for m in re.finditer(r'\t(\w+) = \{[^\n]*\n((?:\t\t"[#.]{9}",\n){9})', src):
    glyphs[m.group(1)] = re.findall(r'"([#.]{9})"', m.group(2))
fam = {'UPGRADE': 'green', 'NOT_AN_UPGRADE': 'grey', 'SLIGHT_UPGRADE': 'yellow', 'MIXED': 'yellow', 'TEMPORARY_UPGRADE': 'yellow', 'FUTURE_UPGRADE': 'yellow', 'COMBAT_UTILITY': 'blue', 'FUTURE_USE': 'purple', 'VENDOR': 'gold', 'NOT_USABLE': 'red', 'UNKNOWN': 'grey', 'RECOMMENDED': 'star', 'TENTATIVE': 'star'}
col = {'green': (143, 204, 133), 'yellow': (255, 214, 92), 'red': (235, 97, 82), 'blue': (128, 184, 255), 'purple': (199, 153, 235), 'gold': (217, 184, 102), 'grey': (179, 173, 158), 'star': (255, 209, 51)}
order = ['UPGRADE', 'NOT_AN_UPGRADE', 'SLIGHT_UPGRADE', 'MIXED', 'TEMPORARY_UPGRADE', 'FUTURE_UPGRADE', 'COMBAT_UTILITY', 'FUTURE_USE', 'VENDOR', 'NOT_USABLE', 'UNKNOWN', 'RECOMMENDED', 'TENTATIVE']
assert len(glyphs) == 13, len(glyphs)
K, pad = 12, 14
B = 11 * K
W = pad + len(order) * (B + pad)
H = pad + B + pad + B // 2 + pad
px = [[(40, 34, 26)] * W for _ in range(H)]
def put(x, y, c):
    if 0 <= x < W and 0 <= y < H: px[y][x] = c
def badge(ox, oy, g, k, star):
    s, e = 11 * k, max(1, k // 4)
    for y in range(s):
        for x in range(s):
            edge = x < e or y < e or x >= s - e or y >= s - e
            put(ox + x, oy + y, (255, 209, 51) if (edge and star) else (97, 84, 51) if edge else (23, 23, 26))
    for r, row in enumerate(glyphs[g]):
        for q, ch in enumerate(row):
            if ch == '#':
                for y in range(k):
                    for x in range(k): put(ox + k + q * k + x, oy + k + r * k + y, col[fam[g]])
for i, g in enumerate(order):
    ox = pad + i * (B + pad)
    badge(ox, pad, g, K, fam[g] == 'star')
    badge(ox, pad + B + pad, g, 3, fam[g] == 'star')
raw = b''.join(b'\x00' + bytes(v for p in row for v in p) for row in px)
def ch(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
open('docs/codex_icons_preview.png', 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw)) + ch(b'IEND', b''))
