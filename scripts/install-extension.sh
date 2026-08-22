#!/usr/bin/env bash
# Register the VideoCorner chrome extension and migrate pre-src installs.
set -euo pipefail

FLAGS_FILE="${CHROMIUM_FLAGS_FILE:-$HOME/.config/chromium-flags.conf}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_PATH="$(realpath -m "$SCRIPT_DIR/../chrome-extension/src")"
LEGACY_PATH="$(realpath -m "$SCRIPT_DIR/../chrome-extension")"
AUTOPLAY_FLAG="--autoplay-policy=no-user-gesture-required"

replace_flags() {
  local tmp="$1"
  chmod --reference="$FLAGS_FILE" "$tmp"
  mv "$tmp" "$FLAGS_FILE"
}

if [[ ! -f "$FLAGS_FILE" ]]; then
  printf '%s\n' "--load-extension=$EXT_PATH" "$AUTOPLAY_FLAG" >"$FLAGS_FILE"
  echo "Created $FLAGS_FILE with the VideoCorner settings."
  exit 0
fi

if ! grep -Fqx -- "$AUTOPLAY_FLAG" "$FLAGS_FILE"; then
  printf '%s\n' "$AUTOPLAY_FLAG" >>"$FLAGS_FILE"
fi

# Rewrite only exact VideoCorner entries. Unrelated Chromium flags and
# unrelated extension entries remain byte-for-byte unchanged.
tmp="$(mktemp)"
awk -v legacy="$LEGACY_PATH" -v current="$EXT_PATH" '
  /^--load-extension=/ {
    prefix = "--load-extension="
    list = substr($0, length(prefix) + 1)
    count = split(list, parts, ",")
    line = prefix
    outputCount = 0
    changed = 0
    currentSeen = 0
    for (i = 1; i <= count; i++) {
      entry = parts[i]
      if (entry == legacy) { entry = current; changed = 1 }
      if (entry == current && currentSeen++) { changed = 1; continue }
      line = line (outputCount++ ? "," : "") entry
    }
    print (changed ? line : $0)
    next
  }
  { print }
' "$FLAGS_FILE" >"$tmp"
if ! cmp -s "$tmp" "$FLAGS_FILE"; then replace_flags "$tmp"; else rm -f "$tmp"; fi

if awk -v current="$EXT_PATH" '
  /^--load-extension=/ {
    list = substr($0, length("--load-extension=") + 1)
    count = split(list, parts, ",")
    for (i = 1; i <= count; i++) if (parts[i] == current) found = 1
  }
  END { exit !found }
' "$FLAGS_FILE"; then
  echo "VideoCorner extension already registered in $FLAGS_FILE."
else
  tmp="$(mktemp)"
  awk -v current="$EXT_PATH" '
    /^--load-extension=/ && !added {
      print $0 "," current
      added = 1
      next
    }
    { print }
    END { if (!added) print "--load-extension=" current }
  ' "$FLAGS_FILE" >"$tmp"
  replace_flags "$tmp"
  echo "Registered VideoCorner extension in $FLAGS_FILE."
fi

echo "Restart Chromium for the change to take effect."
