#!/bin/bash
set -u
P="/mnt/c/Users/hp/Desktop/Custom OS"
for f in "$P/screenshots/"*.png; do
  python3 "$P/scripts/dev/png-preview.py" "$f"
  echo
done
