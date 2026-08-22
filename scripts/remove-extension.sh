#!/usr/bin/env bash
# Remove the VideoCorner extension registration, including legacy installs.
set -euo pipefail

FLAGS_FILE="${CHROMIUM_FLAGS_FILE:-$HOME/.config/chromium-flags.conf}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_PATH="$(realpath -m "$SCRIPT_DIR/../chrome-extension/src")"
LEGACY_PATH="$(realpath -m "$SCRIPT_DIR/../chrome-extension")"

if [[ ! -f "$FLAGS_FILE" ]]; then
  echo "No chromium flags file; nothing to remove."
  exit 0
fi

tmp="$(mktemp)"
awk -v current="$EXT_PATH" -v legacy="$LEGACY_PATH" '
  /^--load-extension=/ {
    prefix = "--load-extension="
    list = substr($0, length(prefix) + 1)
    count = split(list, parts, ",")
    line = prefix
    outputCount = 0
    changed = 0
    for (i = 1; i <= count; i++) {
      if (parts[i] == current || parts[i] == legacy) { changed = 1; continue }
      line = line (outputCount++ ? "," : "") parts[i]
    }
    if (changed && outputCount == 0) next
    print (changed ? line : $0)
    next
  }
  { print }
' "$FLAGS_FILE" >"$tmp"

if cmp -s "$tmp" "$FLAGS_FILE"; then
  rm -f "$tmp"
  echo "VideoCorner extension not registered; nothing to remove."
  exit 0
fi

chmod --reference="$FLAGS_FILE" "$tmp"
mv "$tmp" "$FLAGS_FILE"
echo "Removed VideoCorner extension from $FLAGS_FILE."
echo "Restart Chromium for the change to take effect."
