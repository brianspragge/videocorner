#!/bin/bash
set -u

URL="$1"
X="$2"
Y="$3"
W="$4"
H="$5"

PLUGIN_DIR="$HOME/.config/omarchy/plugins/bms.videocorner"

if ! python3 "$PLUGIN_DIR/player-ipc.py" close; then
    exit 1
fi

python3 "$PLUGIN_DIR/player-ipc.py" open "$URL" "$X" "$Y" "$W" "$H"
