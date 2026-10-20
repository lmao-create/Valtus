#!/bin/bash
# Concatenate build.part1.sh + build.part2.sh into build.sh, syntax check it.
set -u
P="/mnt/c/Users/hp/Desktop/Custom OS/scripts"
cat "$P/build.part1.sh" "$P/build.part2.sh" > "$P/build.sh"
rm -f "$P/build.part1.sh" "$P/build.part2.sh"
bash -n "$P/build.sh" && echo "build.sh syntax OK"
wc -l "$P/build.sh"
chmod +x "$P/build.sh"
