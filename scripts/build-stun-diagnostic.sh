#!/usr/bin/env bash
# Cross-build the isolated libjuice/STUN diagnostic for the Smart Pro S.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$ROOT_DIR/.tsps-build"
SYSROOT="$CACHE_DIR/sysroot"
CXX_OVERLAY_DIR="$CACHE_DIR/gcc10-cxx-headers"
OUTPUT_DIR="$CACHE_DIR/stun-diagnostic"
OUTPUT="$OUTPUT_DIR/apotris-stun-diagnostic"
COMPILER='aarch64-linux-gnu-gcc-10'
GCC_INCLUDE_DIR='/usr/lib/gcc-cross/aarch64-linux-gnu/10/include'
JUICE_DIR="$ROOT_DIR/subprojects/libdatachannel/deps/libjuice"

require() {
    [[ -e "$1" ]] || {
        printf 'Missing prerequisite: %s\n' "$1" >&2
        exit 1
    }
}

command -v "$COMPILER" >/dev/null 2>&1 || {
    printf 'Missing prerequisite: %s\n' "$COMPILER" >&2
    exit 1
}
for path in "$SYSROOT/lib/aarch64-linux-gnu/libc-2.28.so" \
    "$SYSROOT/usr/lib/aarch64-linux-gnu/libpthread.so" \
    "$CXX_OVERLAY_DIR/cstddef" "$JUICE_DIR/include/juice/juice.h"; do
    require "$path"
done

mapfile -t juice_sources < <(find "$JUICE_DIR/src" -maxdepth 1 -name '*.c' -print | sort)
(( ${#juice_sources[@]} > 0 )) || {
    printf 'No libjuice sources found in: %s\n' "$JUICE_DIR/src" >&2
    exit 1
}

mkdir -p "$OUTPUT_DIR"
"$COMPILER" \
    --sysroot="$SYSROOT" -B"$SYSROOT/usr/lib/aarch64-linux-gnu" \
    -nostdinc \
    -isystem "$SYSROOT/usr/include/aarch64-linux-gnu" \
    -isystem "$SYSROOT/usr/include" \
    -idirafter "$GCC_INCLUDE_DIR" \
    -march=armv8-a -O2 -DNDEBUG -DJUICE_STATIC \
    -I"$JUICE_DIR/include" -I"$JUICE_DIR/include/juice" -I"$JUICE_DIR/src" \
    "$ROOT_DIR/diagnostics/apotris-stun-diagnostic.c" "${juice_sources[@]}" \
    -o "$OUTPUT" \
    -Wl,--dynamic-linker=/lib/ld-linux-aarch64.so.1 \
    -pthread

readelf -h "$OUTPUT" | grep -q 'Machine:.*AArch64' || {
    printf 'Diagnostic is not an aarch64 ELF: %s\n' "$OUTPUT" >&2
    exit 1
}
if readelf -d "$OUTPUT" | grep -qE 'NEEDED.*(libjuice|libssl|libcrypto)'; then
    printf 'Unexpected runtime networking dependency in: %s\n' "$OUTPUT" >&2
    exit 1
fi
mapfile -t glibc_versions < <(readelf --version-info "$OUTPUT" | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sed 's/GLIBC_//' | sort -Vu)
for version in "${glibc_versions[@]}"; do
    if [[ "$(printf '%s\n%s\n' 2.33 "$version" | sort -V | tail -n1)" != 2.33 ]]; then
        printf 'GLIBC %s exceeds the console maximum 2.33\n' "$version" >&2
        exit 1
    fi
done

printf 'STUN diagnostic built: %s\n' "$OUTPUT"
