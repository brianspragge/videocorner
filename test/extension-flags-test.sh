#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$ROOT/scripts/install-extension.sh"
REMOVE="$ROOT/scripts/remove-extension.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CURRENT="$ROOT/chrome-extension/src"
LEGACY="$ROOT/chrome-extension"
AUTO="--autoplay-policy=no-user-gesture-required"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_file() {
  local expected="$1" actual="$2" label="$3"
  cmp -s "$expected" "$actual" || { printf '%s\n' "--- expected" "$(<"$expected")" "--- actual" "$(<"$actual")"; fail "$label"; }
}

# Migration replaces only exact entries and preserves unrelated duplicates and
# separate --load-extension lines.
cat >"$TMP_DIR/migrate" <<EOF
--other-flag=value
--load-extension=/opt/one,$LEGACY,/opt/one
--load-extension=/opt/two,$LEGACY,$CURRENT,/opt/two
$AUTO
EOF
cat >"$TMP_DIR/migrate.expected" <<EOF
--other-flag=value
--load-extension=/opt/one,$CURRENT,/opt/one
--load-extension=/opt/two,$CURRENT,/opt/two
$AUTO
EOF
CHROMIUM_FLAGS_FILE="$TMP_DIR/migrate" "$INSTALL" >/dev/null
assert_file "$TMP_DIR/migrate.expected" "$TMP_DIR/migrate" "legacy migration"
cp "$TMP_DIR/migrate" "$TMP_DIR/migrate.once"
CHROMIUM_FLAGS_FILE="$TMP_DIR/migrate" "$INSTALL" >/dev/null
assert_file "$TMP_DIR/migrate.once" "$TMP_DIR/migrate" "installer idempotency"

# Removal handles both layouts while preserving unrelated entries.
cat >"$TMP_DIR/remove" <<EOF
--load-extension=/opt/a,$LEGACY,/opt/b,$CURRENT,/opt/c
--other-flag=value
$AUTO
EOF
cat >"$TMP_DIR/remove.expected" <<EOF
--load-extension=/opt/a,/opt/b,/opt/c
--other-flag=value
$AUTO
EOF
CHROMIUM_FLAGS_FILE="$TMP_DIR/remove" "$REMOVE" >/dev/null
assert_file "$TMP_DIR/remove.expected" "$TMP_DIR/remove" "extension removal"

# Atomic replacement preserves the existing flags-file mode.
cat >"$TMP_DIR/mode" <<EOF
--load-extension=$LEGACY
EOF
chmod 640 "$TMP_DIR/mode"
CHROMIUM_FLAGS_FILE="$TMP_DIR/mode" "$INSTALL" >/dev/null
[[ "$(stat -c '%a' "$TMP_DIR/mode")" == 640 ]] || fail "installer mode preservation"

printf 'extension flag tests passed\n'
