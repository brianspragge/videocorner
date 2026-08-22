#!/usr/bin/env bash
# Remove the VideoCorner chrome extension registration, leaving all other
# chromium flags untouched. Idempotent.
set -euo pipefail

FLAGS_FILE="${CHROMIUM_FLAGS_FILE:-$HOME/.config/chromium-flags.conf}"
EXT_PATH="$HOME/.config/omarchy/plugins/bms.videocorner/chrome-extension"

if [[ ! -f "$FLAGS_FILE" ]]; then
  echo "No chromium flags file; nothing to remove."
  exit 0
fi

if ! grep -q -- "$EXT_PATH" "$FLAGS_FILE"; then
  echo "VideoCorner extension not registered; nothing to remove."
  exit 0
fi

# If the --load-extension= line contains only this path, remove the whole line;
# otherwise strip just this entry (with its leading comma).
if grep -q "^--load-extension=$EXT_PATH\$" "$FLAGS_FILE"; then
  sed -i "\|^--load-extension=$EXT_PATH$|d" "$FLAGS_FILE"
else
  sed -i "s|,$EXT_PATH||g; s|$EXT_PATH,||g" "$FLAGS_FILE"
fi

echo "Removed VideoCorner extension from $FLAGS_FILE."
echo "Restart Chromium for the change to take effect."
