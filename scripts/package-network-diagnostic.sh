#!/usr/bin/env bash
# Package the temporary network probe as a standalone Spruce/PortMaster script.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE="$DIST_DIR/apotris-network-diagnostic.zip"
PROBE="$ROOT_DIR/portmaster/Apotris-network-diagnostic.sh"

command -v zip >/dev/null 2>&1 || {
    printf '%s\n' 'Missing prerequisite: zip' >&2
    exit 1
}
[[ -f "$PROBE" ]] || {
    printf 'Missing diagnostic script: %s\n' "$PROBE" >&2
    exit 1
}

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
(
    cd "$ROOT_DIR/portmaster"
    zip -q "$ARCHIVE" "$(basename "$PROBE")"
)

printf 'Network diagnostic package created: %s\n' "$ARCHIVE"
