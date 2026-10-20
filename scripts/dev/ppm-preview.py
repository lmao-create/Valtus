#!/usr/bin/env python3
"""ASCII preview of a QEMU screendump PPM."""
import sys

path = sys.argv[1]
data = open(path, "rb").read()
# parse P6 header
parts = data.split(b"\n", 3)
w, h = map(int, parts[1].split())
pix = parts[3]
chars = " .:-=+*#%@"
rows = []
for y in range(0, h, max(1, h // 28)):
    row = ""
    for x in range(0, w, max(1, w // 76)):
        off = (y * w + x) * 3
        r, g, b = pix[off], pix[off + 1], pix[off + 2]
        lum = (r * 30 + g * 59 + b * 11) // 100
        row += chars[min(9, lum * 10 // 256)]
    rows.append(row)
print(f"{path}: {w}x{h}")
print("\n".join(rows))
