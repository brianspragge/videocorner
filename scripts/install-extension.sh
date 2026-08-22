#!/usr/bin/env bash
# Register the VideoCorner chrome extension so the player window uses the
# video-only layout. Idempotent: appends only if not already present and
# preserves all other chromium flags.
set -euo pipefail

FLAGS_FILE="${CHROMIUM_FLAGS_FILE:-$HOME/.config/chromium-flags.conf}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_PATH="$(realpath -m "$SCRIPT_DIR/../chrome-extension/src")"
AUTOPLAY_FLAG="--autoplay-policy=no-user-gesture-required"

if [[ ! -f "$FLAGS_FILE" ]]; then
  printf '%s\n' "--load-extension=$EXT_PATH" "$AUTOPLAY_FLAG" >"$FLAGS_FILE"
  echo "Created $FLAGS_FILE with the VideoCorner settings."
  exit 0
fi

if ! grep -Fqx -- "$AUTOPLAY_FLAG" "$FLAGS_FILE"; then
  printf '%s\n' "$AUTOPLAY_FLAG" >>"$FLAGS_FILE"
  echo "Registered the VideoCorner autoplay policy in $FLAGS_FILE."
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
