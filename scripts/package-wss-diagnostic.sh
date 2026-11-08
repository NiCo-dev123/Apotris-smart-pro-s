#!/usr/bin/env bash
# Build and package the experimental libdatachannel WSS diagnostic.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-spruce-aarch64"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/apotris-wss-diagnostic-port"
ARCHIVE="$DIST_DIR/apotris-wss-diagnostic.zip"
BINARY="$BUILD_DIR/apotris-wss-diagnostic"
LAUNCHER="$ROOT_DIR/portmaster/Apotris-wss-diagnostic.sh"

command -v zip >/dev/null 2>&1 || {
    printf '%s\n' 'Missing prerequisite: zip' >&2
    exit 1
}
PORTMASTER_WSS_DIAGNOSTIC=1 "$ROOT_DIR/scripts/build-tsps.sh"

[[ -x "$BINARY" ]] || {
    printf 'Missing WSS diagnostic after online build: %s\n' "$BINARY" >&2
    exit 1
}

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/apotris-wss-diagnostic/assets/ssl"
cp "$LAUNCHER" "$STAGE_DIR/Apotris-wss-diagnostic.sh"
cp "$BINARY" "$STAGE_DIR/apotris-wss-diagnostic/apotris-wss-diagnostic"
cp "$ROOT_DIR/assets/ssl/cacert.pem" \
    "$STAGE_DIR/apotris-wss-diagnostic/assets/ssl/cacert.pem"
cp "$ROOT_DIR/subprojects/libdatachannel/LICENSE" \
    "$STAGE_DIR/apotris-wss-diagnostic/LICENSE.libdatachannel.txt"
cp "$ROOT_DIR/subprojects/libdatachannel/deps/libjuice/LICENSE" \
    "$STAGE_DIR/apotris-wss-diagnostic/LICENSE.libjuice.txt"
cp "$ROOT_DIR/subprojects/libdatachannel/deps/usrsctp/LICENSE.md" \
    "$STAGE_DIR/apotris-wss-diagnostic/LICENSE.usrsctp.txt"
chmod +x "$STAGE_DIR/Apotris-wss-diagnostic.sh" \
    "$STAGE_DIR/apotris-wss-diagnostic/apotris-wss-diagnostic"

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
(
    cd "$STAGE_DIR"
    zip -qr "$ARCHIVE" Apotris-wss-diagnostic.sh apotris-wss-diagnostic
)
printf 'WSS diagnostic package created: %s\n' "$ARCHIVE"
