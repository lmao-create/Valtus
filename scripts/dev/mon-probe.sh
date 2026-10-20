#!/bin/bash
set -u
W=/root/valtus-vm-test-20261020-121513
{
  printf 'screendump /tmp/shot.ppm\n'
  sleep 2
  printf 'info status\n'
  sleep 1
  printf 'info block\n'
  sleep 1
  printf 'info roms\n'
  sleep 1
  printf 'quit\n'
} | socat - "UNIX-CONNECT:$W/monitor.sock" 2>/dev/null | tr -d '\r' | tail -25
ls -la /tmp/shot.ppm 2>/dev/null
python3 - <<'PY'
from PIL import Image
try:
    im = Image.open('/tmp/shot.ppm')
    print("screenshot:", im.size, im.mode)
    im.convert('L').resize((80, 30)).save('/tmp/shot.txt')
    txt = open('/tmp/shot.txt','rb').read()
    # crude ascii preview
    chars = " .:-=+*#%@"
    px = open('/tmp/shot.ppm','rb').read()
    # parse P6
    parts = px.split(b'\n', 3)
    hdr = parts[0:3]
    data = parts[3]
    import re
    w,h = map(int, hdr[1].split())
    out = []
    for y in range(0, h, h//25):
        row = ""
        for x in range(0, w, w//70):
            off = (y*w + x)*3
            r,g,b = data[off], data[off+1], data[off+2]
            lum = (r+g+b)//3
            row += chars[min(9, lum*10//256)]
        out.append(row)
    print('\n'.join(out))
except Exception as e:
    print("preview failed:", e)
PY
