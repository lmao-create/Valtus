#!/bin/bash
# ASCII-preview the captured screenshots and inspect this run's serial log
# for what happened after the sendkey login.
set -u
S="/mnt/c/Users/hp/Desktop/Custom OS/screenshots"
for f in "$S"/*.png; do
  echo "=== $f ($(stat -c %s "$f") bytes) ==="
  python3 /mnt/c/Users/hp/Desktop/Custom\ OS/scripts/dev/ppm-preview.py "$f" 2>/dev/null | head -14 || echo "(preview failed)"
done
echo
echo "=== serial log after sendkeys (kwin/plasma/errors) ==="
L=/root/valtus-gui/serial.log
grep -a -iE "kwin|plasmashell|wayland|egl|gbm|drm|failed|error" "$L" | tail -25
