#!/bin/zsh
# Compare ways of turning the 3D lock into terminal art: renders high-resolution frames, then converts the
# shut and open frames with chafa symbol sets side by side. Needs node and chafa (brew install chafa).
cd ${0:A:h:h}; D=$(mktemp -d -t amc-lock)
node tools/lock3d.mjs --png $D >/dev/null || exit 1
typeset -A SETS
SETS=(blocks "block+space" quadrants "quad+half+space+solid" braille "braille+space" ascii "ascii+space" all "all-wide")
for f in 00 21; do
  print "\n  frame $f (left to right: ${(k)SETS})"
  cols=()
  for name set in ${(kv)SETS}; do
    cols+=("$(chafa -f symbols --symbols $set -c full --color-extractor median --dither none --size 22x11 --bg 1e1e1e $D/lock-$f.png)")
  done
  paste -d '   ' <(print -r -- $cols[1]) <(print -r -- $cols[2]) <(print -r -- $cols[3]) <(print -r -- $cols[4]) <(print -r -- $cols[5])
done
rm -rf $D
