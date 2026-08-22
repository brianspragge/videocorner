#!/bin/bash
set -u

X="$1"
Y="$2"
W="$3"
H="$4"

python3 "$HOME/.config/omarchy/plugins/bms.videocorner/player-ipc.py" position "$X" "$Y" "$W" "$H"
