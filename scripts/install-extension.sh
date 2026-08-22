#!/usr/bin/env bash
# Register the VideoCorner chrome extension so the player window uses the
# video-only layout. Idempotent: appends only if not already present and
# preserves all other chromium flags.
set -euo pipefail

FLAGS_FILE="${CHROMIUM_FLAGS_FILE:-$HOME/.config/chromium-flags.conf}"
EXT_PATH="$HOME/.config/omarchy/plugins/bms.videocorner/chrome-extension"

if [[ ! -f "$FLAGS_FILE" ]]; then
  echo "--load-extension=$EXT_PATH" >"$FLAGS_FILE"
  echo "Created $FLAGS_FILE with the VideoCorner extension."
  exit 0
fi

if grep -q -- "$EXT_PATH" "$FLAGS_FILE"; then
  echo "VideoCorner extension already registered in $FLAGS_FILE."
  exit 0
fi

# Append to an existing --load-extension= line, or add one if absent.
if grep -q '^--load-extension=' "$FLAGS_FILE"; then
  sed -i "s|^--load-extension=\(.*\)$|--load-extension=\1,$EXT_PATH|" "$FLAGS_FILE"
else
  echo "--load-extension=$EXT_PATH" >>"$FLAGS_FILE"
fi

echo "Registered VideoCorner extension in $FLAGS_FILE."
echo "Restart Chromium for the change to take effect."
