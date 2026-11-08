#!/usr/bin/env bash
# Build and package an isolated experimental online PortMaster profile.
# It never modifies the stable apotris.zip package or its installation path.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-spruce-aarch64"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/apotris-online-test-port"
ARCHIVE="$DIST_DIR/apotris-online-test.zip"
BINARY="$BUILD_DIR/Apotris"
SDL2_RUNTIME="$ROOT_DIR/runtime/aarch64/libsdl2.so"
SDL2_LICENSE="$ROOT_DIR/runtime/aarch64/LICENSE.SDL2.txt"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Missing prerequisite: %s\n' "$1" >&2
        exit 1
    }
}

require_at_most() {
    local label="$1" maximum="$2" version
    shift 2
    for version in "$@"; do
        if [[ "$(printf '%s\n%s\n' "$maximum" "$version" | sort -V | tail -n1)" != "$maximum" ]]; then
            printf '%s %s exceeds the Trimui Smart Pro S maximum %s\n' \
                "$label" "$version" "$maximum" >&2
            exit 1
        fi
    done
}

for command in readelf zip cp find sort; do
    require_command "$command"
done

PORTMASTER_ONLINE=1 "$ROOT_DIR/scripts/build-tsps.sh"

[[ -x "$BINARY" ]] || {
    printf 'Missing online build artifact: %s\n' "$BINARY" >&2
    exit 1
}
[[ -f "$SDL2_RUNTIME" && -f "$SDL2_LICENSE" ]] || {
    printf '%s\n' 'Missing validated SDL2 runtime or its license.' >&2
    exit 1
}

readelf -h "$BINARY" | grep -q 'Machine:.*AArch64' || {
    printf 'Online build is not AArch64: %s\n' "$BINARY" >&2
    exit 1
}
mapfile -t glibc_versions < <(readelf --version-info "$BINARY" | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sed 's/GLIBC_//' | sort -Vu)
mapfile -t glibcxx_versions < <(readelf --version-info "$BINARY" | grep -oE 'GLIBCXX_[0-9]+\.[0-9]+(\.[0-9]+)?' | sed 's/GLIBCXX_//' | sort -Vu)
mapfile -t cxxabi_versions < <(readelf --version-info "$BINARY" | grep -oE 'CXXABI_[0-9]+(\.[0-9]+)+' | sed 's/CXXABI_//' | sort -Vu)
require_at_most GLIBC 2.33 "${glibc_versions[@]}"
require_at_most GLIBCXX 3.4.28 "${glibcxx_versions[@]}"
require_at_most CXXABI 1.3.13 "${cxxabi_versions[@]}"

printf '%s\n' 'Online executable dynamic dependencies:'
readelf -d "$BINARY" | awk '/NEEDED/ {gsub(/[\[\]]/, "", $NF); print "  " $NF}'

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/apotris-online-test/lib"

cp "$ROOT_DIR/portmaster/Apotris-online-test.sh" "$STAGE_DIR/Apotris-online-test.sh"
cp "$ROOT_DIR/portmaster/port-online-test.json" "$STAGE_DIR/apotris-online-test/port.json"
cp "$ROOT_DIR/portmaster/gameinfo-online-test.xml" "$STAGE_DIR/apotris-online-test/gameinfo.xml"
cp "$BINARY" "$STAGE_DIR/apotris-online-test/Apotris"
cp -a "$ROOT_DIR/assets" "$STAGE_DIR/apotris-online-test/assets"
cp "$SDL2_RUNTIME" "$STAGE_DIR/apotris-online-test/lib/libsdl2.so"
cp "$SDL2_LICENSE" "$STAGE_DIR/apotris-online-test/lib/LICENSE.SDL2.txt"

# The online profile statically incorporates these projects.  Ship their
# notices with the test package before promoting it beyond local testing.
cp "$ROOT_DIR/subprojects/cpr-1.11.2/LICENSE" \
    "$STAGE_DIR/apotris-online-test/LICENSE.cpr.txt"
cp "$ROOT_DIR/subprojects/curl-8.12.1/COPYING" \
    "$STAGE_DIR/apotris-online-test/LICENSE.curl.txt"
cp "$ROOT_DIR/subprojects/openssl-3.0.8/LICENSE.txt" \
    "$STAGE_DIR/apotris-online-test/LICENSE.openssl.txt"
cp "$ROOT_DIR/subprojects/libdatachannel/LICENSE" \
    "$STAGE_DIR/apotris-online-test/LICENSE.libdatachannel.txt"
cp "$ROOT_DIR/subprojects/libdatachannel/deps/libjuice/LICENSE" \
    "$STAGE_DIR/apotris-online-test/LICENSE.libjuice.txt"
cp "$ROOT_DIR/subprojects/libdatachannel/deps/usrsctp/LICENSE.md" \
    "$STAGE_DIR/apotris-online-test/LICENSE.usrsctp.txt"
chmod +x "$STAGE_DIR/Apotris-online-test.sh" "$STAGE_DIR/apotris-online-test/Apotris"

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
(
    cd "$STAGE_DIR"
    zip -qr "$ARCHIVE" Apotris-online-test.sh apotris-online-test
)

printf 'Online test PortMaster package created: %s\n' "$ARCHIVE"
