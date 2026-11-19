#!/bin/sh
# herdr tab bar, right side (ui.tab_bar_right in config.toml).
#
# Runs every executable in tab-bar-right.d/, in name order, and joins their
# non-empty first lines with two spaces. The directory is a drop-in point for
# readouts that do not belong in this repo; with nothing there, this prints
# nothing and the entry stays empty. The whole run shares herdr's 5s timeout.

dir=${XDG_CONFIG_HOME:-$HOME/.config}/herdr/tab-bar-right.d
out=""
for f in "$dir"/*; do
  [ -f "$f" ] && [ -x "$f" ] || continue
  line=$("$f" </dev/null 2>/dev/null | head -n1)
  [ -n "$line" ] || continue
  out="${out:+$out  }$line"
done
[ -n "$out" ] && printf '%s\n' "$out"
exit 0
