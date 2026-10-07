#!/usr/bin/env python3
"""Makes QuestFlow/Media/QuestFlowLogo.tga (the minimap button, the world-map button and the add-on list icon) from the Quest Flow logo, docs/release/questflow-logo.png.

The logo is not redrawn: it is cropped square around its gold ring, scaled to 128 x 128 and given a circular transparent edge (the buttons are round, so the
square corners of the artwork must not show). The result is written in the same format as the other textures in Media/ (generator/make_art.py): uncompressed 32-bit BGRA,
top-left origin, power-of-two size. Needs ImageMagick's `convert` (only for the crop and scale); nothing else. Run from the repository root:

    python3 questflow/generator/make_logo.py
"""
import struct
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "docs" / "release" / "questflow-logo.png"
TARGET = REPO / "questflow" / "QuestFlow" / "Media" / "QuestFlowLogo.tga"
SIZE = 128
CROP = (1110, 72, 67)       # side, x, y: a square around the logo's gold ring in the 1254 x 1254 artwork


def render() -> bytes:
    side, x, y = CROP
    r = SIZE // 2
    cmd = ["convert", str(SOURCE), "-crop", f"{side}x{side}+{x}+{y}", "+repage", "-resize", f"{SIZE}x{SIZE}!",
           "(", "-size", f"{SIZE}x{SIZE}", "xc:black", "-fill", "white", "-draw", f"circle {r},{r} {r},1", ")",
           "-alpha", "off", "-compose", "CopyOpacity", "-composite", "-depth", "8", "rgba:-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    assert len(raw) == SIZE * SIZE * 4, len(raw)
    return raw


def main() -> None:
    raw = render()
    bgra = bytearray(len(raw))
    for i in range(0, len(raw), 4):
        bgra[i], bgra[i + 1], bgra[i + 2], bgra[i + 3] = raw[i + 2], raw[i + 1], raw[i], raw[i + 3]
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    TARGET.write_bytes(header + bytes(bgra))
    print(TARGET, TARGET.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
