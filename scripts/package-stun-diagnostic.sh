#!/usr/bin/env bash
# Package the isolated ICE/STUN diagnostic as a standalone Spruce port.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/apotris-stun-diagnostic-port"
ARCHIVE="$DIST_DIR/apotris-stun-diagnostic.zip"
BINARY="$ROOT_DIR/.tsps-build/stun-diagnostic/apotris-stun-diagnostic"
LAUNCHER="$ROOT_DIR/portmaster/Apotris-stun-diagnostic.sh"

command -v zip >/dev/null 2>&1 || {
    printf '%s\n' 'Missing prerequisite: zip' >&2
    exit 1
}
"$ROOT_DIR/scripts/build-stun-diagnostic.sh"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/apotris-stun-diagnostic"
cp "$LAUNCHER" "$STAGE_DIR/Apotris-stun-diagnostic.sh"
cp "$BINARY" "$STAGE_DIR/apotris-stun-diagnostic/apotris-stun-diagnostic"
cp "$ROOT_DIR/subprojects/libdatachannel/deps/libjuice/LICENSE" \
    "$STAGE_DIR/apotris-stun-diagnostic/LICENSE.libjuice.txt"
chmod +x "$STAGE_DIR/Apotris-stun-diagnostic.sh" \
    "$STAGE_DIR/apotris-stun-diagnostic/apotris-stun-diagnostic"

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
(
    cd "$STAGE_DIR"
    zip -qr "$ARCHIVE" Apotris-stun-diagnostic.sh apotris-stun-diagnostic
)
printf 'STUN diagnostic package created: %s\n' "$ARCHIVE"
