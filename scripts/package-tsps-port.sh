#!/usr/bin/env bash
# Build and package the online aarch64 Apotris release as a PortMaster ZIP.
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

require_aarch64_elf() {
    local artifact="$1"
    if ! readelf -h "$artifact" | grep -q 'Machine:.*AArch64'; then
        printf 'Not an aarch64 ELF: %s\n' "$artifact" >&2
        exit 1
    fi
}

require_expected_needed() {
    local artifact="$1" library expected
    local -a needed expected_needed
    mapfile -t needed < <(readelf -d "$artifact" |
        awk '/NEEDED/ {gsub(/[\[\]]/, "", $NF); print $NF}')
    expected_needed=(
        libstdc++.so.6 libm.so.6 libgcc_s.so.1 libc.so.6
        ld-linux-aarch64.so.1 libpthread.so.0 libsdl2.so libdl.so.2
    )

    for library in "${needed[@]}"; do
        case "$library" in
        libstdc++.so.6|libm.so.6|libgcc_s.so.1|libc.so.6|ld-linux-aarch64.so.1|libpthread.so.0|libsdl2.so|libdl.so.2)
            ;;
        *)
            printf 'Unexpected dynamic dependency in %s: %s\n' \
                "$artifact" "$library" >&2
            exit 1
            ;;
        esac
    done

    for expected in "${expected_needed[@]}"; do
        printf '%s\n' "${needed[@]}" | grep -Fxq "$expected" || {
            printf 'Required dynamic dependency missing in %s: %s\n' \
                "$artifact" "$expected" >&2
            exit 1
        }
    done
}

validate_ca_bundle() {
    local bundle="$1" certificate_count
    [[ -s "$bundle" ]] || {
        printf 'Missing or empty CA bundle: %s\n' "$bundle" >&2
        exit 1
    }
    certificate_count="$(grep -c '^-----BEGIN CERTIFICATE-----$' "$bundle" || true)"
    [[ "$certificate_count" -gt 0 ]] || {
        printf 'No PEM certificates found in CA bundle: %s\n' "$bundle" >&2
        exit 1
    }
    printf 'CA bundle: %s certificates, SHA-256 %s\n' \
        "$certificate_count" "$(sha256sum "$bundle" | awk '{print $1}')"
}

for command in awk cmp grep readelf sed sha256sum sort stat tail unzip zip; do
    require_command "$command"
done

# The published port enables the services validated on the Smart Pro S.
PORTMASTER_ONLINE=1 "$ROOT_DIR/scripts/build-tsps.sh"

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
mapfile -t cxxabi_versions < <(readelf --version-info "$BINARY" | grep -oE 'CXXABI_[0-9]+(\.[0-9]+)+' | sed 's/CXXABI_//' | sort -Vu)
mapfile -t sdl_glibc_versions < <(readelf --version-info "$SDL2_RUNTIME" | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sed 's/GLIBC_//' | sort -Vu)
require_at_most GLIBC 2.33 "${glibc_versions[@]}"
require_at_most GLIBCXX 3.4.28 "${glibcxx_versions[@]}"
require_at_most CXXABI 1.3.13 "${cxxabi_versions[@]}"
require_at_most 'SDL2 GLIBC' 2.33 "${sdl_glibc_versions[@]}"
require_expected_needed "$BINARY"
validate_ca_bundle "$ROOT_DIR/assets/ssl/cacert.pem"

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
cmp "$ROOT_DIR/assets/ssl/cacert.pem" "$STAGE_DIR/apotris/assets/ssl/cacert.pem"

# The online profile statically incorporates these projects.  Include their
# notices in the published archive.
cp "$ROOT_DIR/subprojects/cpr-1.11.2/LICENSE" \
    "$STAGE_DIR/apotris/LICENSE.cpr.txt"
cp "$ROOT_DIR/subprojects/curl-8.12.1/COPYING" \
    "$STAGE_DIR/apotris/LICENSE.curl.txt"
cp "$ROOT_DIR/subprojects/openssl-3.0.8/LICENSE.txt" \
    "$STAGE_DIR/apotris/LICENSE.openssl.txt"
cp "$ROOT_DIR/subprojects/libdatachannel/LICENSE" \
    "$STAGE_DIR/apotris/LICENSE.libdatachannel.txt"
cp "$ROOT_DIR/subprojects/libdatachannel/deps/libjuice/LICENSE" \
    "$STAGE_DIR/apotris/LICENSE.libjuice.txt"
cp "$ROOT_DIR/subprojects/libdatachannel/deps/usrsctp/LICENSE.md" \
    "$STAGE_DIR/apotris/LICENSE.usrsctp.txt"

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
(
    cd "$STAGE_DIR"
    zip -qr "$ARCHIVE" Apotris.sh apotris
)

unzip -tqq "$ARCHIVE"
for package_item in \
    Apotris.sh \
    apotris/Apotris \
    apotris/lib/libsdl2.so \
    apotris/assets/ssl/cacert.pem \
    apotris/LICENSE.cpr.txt \
    apotris/LICENSE.curl.txt \
    apotris/LICENSE.openssl.txt \
    apotris/LICENSE.libdatachannel.txt \
    apotris/LICENSE.libjuice.txt \
    apotris/LICENSE.usrsctp.txt; do
    unzip -Z1 "$ARCHIVE" | grep -Fxq "$package_item" || {
        printf 'Package integrity check failed; missing %s\n' "$package_item" >&2
        exit 1
    }
done

printf 'Online PortMaster release created: %s\n' "$ARCHIVE"
printf 'Sizes: executable %s bytes; ZIP %s bytes\n' \
    "$(stat -c '%s' "$BINARY")" "$(stat -c '%s' "$ARCHIVE")"
