#!/usr/bin/env bash
# Package a successfully built aarch64 Apotris binary as a PortMaster ZIP.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-spruce-aarch64"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/apotris-port"
ARCHIVE="$DIST_DIR/apotris.zip"
BINARY="$BUILD_DIR/Apotris"
SDL2_RUNTIME="$ROOT_DIR/runtime/aarch64/libsdl2.so"
SDL2_LICENSE="$ROOT_DIR/runtime/aarch64/LICENSE.SDL2.txt"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Missing prerequisite: %s\n' "$1" >&2
        exit 1
    }
}

for command in readelf zip cp find sort; do
    require_command "$command"
done

require_aarch64_elf() {
    local artifact="$1"
    if ! readelf -h "$artifact" | grep -q 'Machine:.*AArch64'; then
        printf 'Not an aarch64 ELF: %s\n' "$artifact" >&2
        exit 1
    fi
}

require_at_most() {
    local label="$1"
    local maximum="$2"
    local version
    shift 2
    for version in "$@"; do
        if [[ "$(printf '%s\n%s\n' "$maximum" "$version" | sort -V | tail -n1)" != "$maximum" ]]; then
            printf '%s %s exceeds the Trimui Smart Pro S maximum %s\n' \
                "$label" "$version" "$maximum" >&2
            exit 1
        fi
    done
}

if [[ ! -x "$BINARY" ]]; then
    printf 'Missing build artifact: %s\nRun ./scripts/build-tsps.sh first.\n' "$BINARY" >&2
    exit 1
fi

if [[ ! -f "$SDL2_RUNTIME" || ! -f "$SDL2_LICENSE" ]]; then
    printf 'Missing validated SDL2 runtime or its license in runtime/aarch64.\n' >&2
    exit 1
fi

require_aarch64_elf "$BINARY"
require_aarch64_elf "$SDL2_RUNTIME"
if ! readelf -d "$SDL2_RUNTIME" | grep -q 'SONAME.*libSDL2-2.0.so.0'; then
    printf 'Unexpected SDL2 SONAME: %s\n' "$SDL2_RUNTIME" >&2
    exit 1
fi

mapfile -t glibc_versions < <(readelf --version-info "$BINARY" | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sed 's/GLIBC_//' | sort -Vu)
mapfile -t glibcxx_versions < <(readelf --version-info "$BINARY" | grep -oE 'GLIBCXX_[0-9]+\.[0-9]+(\.[0-9]+)?' | sed 's/GLIBCXX_//' | sort -Vu)
mapfile -t sdl_glibc_versions < <(readelf --version-info "$SDL2_RUNTIME" | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sed 's/GLIBC_//' | sort -Vu)
require_at_most GLIBC 2.33 "${glibc_versions[@]}"
require_at_most GLIBCXX 3.4.28 "${glibcxx_versions[@]}"
require_at_most 'SDL2 GLIBC' 2.33 "${sdl_glibc_versions[@]}"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/apotris/lib"

cp "$ROOT_DIR/portmaster/Apotris.sh" "$STAGE_DIR/Apotris.sh"
chmod +x "$STAGE_DIR/Apotris.sh"
cp "$ROOT_DIR/portmaster/port.json" "$STAGE_DIR/apotris/port.json"
cp "$ROOT_DIR/portmaster/gameinfo.xml" "$STAGE_DIR/apotris/gameinfo.xml"
cp "$BINARY" "$STAGE_DIR/apotris/Apotris"
cp -a "$ROOT_DIR/assets" "$STAGE_DIR/apotris/assets"

# The executable was linked with NEEDED=libsdl2.so, hence this intentional name.
cp "$SDL2_RUNTIME" "$STAGE_DIR/apotris/lib/libsdl2.so"
cp "$SDL2_LICENSE" "$STAGE_DIR/apotris/lib/LICENSE.SDL2.txt"

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
(
    cd "$STAGE_DIR"
    zip -qr "$ARCHIVE" Apotris.sh apotris
)

printf 'PortMaster package created: %s\n' "$ARCHIVE"
