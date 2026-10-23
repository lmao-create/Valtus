#!/usr/bin/env python3
"""ASCII preview of a PNG screenshot (works for any PIL-readable image)."""
import sys
from PIL import Image

path = sys.argv[1]
im = Image.open(path).convert("L")
w, h = im.size
chars = " .:-=+*#%@"
print(f"{path}: {w}x{h}")
rows = []
for y in range(0, h, max(1, h // 28)):
    row = ""
    for x in range(0, w, max(1, w // 76)):
        lum = im.getpixel((min(x, w - 1), min(y, h - 1)))
        row += chars[min(9, lum * 10 // 256)]
    rows.append(row)
print("\n".join(rows))
# blankness metric
extremes = im.getextrema()
print(f"luminance extrema: {extremes}")
mean = sum(im.histogram()) and sum(i * c for i, c in enumerate(im.histogram())) / (w * h)
print(f"mean luminance: {mean:.2f} (0=black, 255=white)")
