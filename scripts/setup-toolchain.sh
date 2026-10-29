#!/usr/bin/env bash
# Prepare the local aarch64 toolchain for Trimui Smart Pro S builds.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$ROOT_DIR/.tsps-build"
SYSROOT="$CACHE_DIR/sysroot"
TOOLS_DIR="$CACHE_DIR/tools"
VENV_DIR="$TOOLS_DIR/venv"
STUB_DIR="$CACHE_DIR/link-stubs"
READY_FILE="$CACHE_DIR/toolchain-aarch64.ready"
C_COMPILER='aarch64-linux-gnu-gcc-10'
CXX_COMPILER='aarch64-linux-gnu-g++-10'
GCC_INCLUDE_DIR='/usr/lib/gcc-cross/aarch64-linux-gnu/10/include'
CXX_INCLUDE_DIR='/usr/aarch64-linux-gnu/include/c++/10'
CXX_OVERLAY_DIR="$CACHE_DIR/gcc10-cxx-headers"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Missing prerequisite: %s\n' "$1" >&2
        exit 1
    }
}

fetch_deb() {
    local directory="$1"
    local package="$2"
    local deb="$CACHE_DIR/$package"
    local partial="$deb.partial"

    if ! dpkg-deb --contents "$deb" >/dev/null 2>&1; then
        rm -f "$deb" "$partial"
        curl --fail --location --retry 3 "$directory/$package" --output "$partial"
        dpkg-deb --contents "$partial" >/dev/null
        mv "$partial" "$deb"
    fi
    printf '%s\n' "$deb"
}

missing_host_tool=false
for command in "$C_COMPILER" "$CXX_COMPILER" curl dpkg-deb readelf ninja python3; do
    command -v "$command" >/dev/null 2>&1 || missing_host_tool=true
done

if [[ "$missing_host_tool" == true ]]; then
    printf '%s\n' 'Installing missing Ubuntu build prerequisites (sudo required)...'
    # Do not run apt-get update: unrelated broken PPAs must not block a build.
    sudo apt-get install -y \
        gcc-10-aarch64-linux-gnu g++-10-aarch64-linux-gnu \
        ninja-build python3 python3-venv python3-pip \
        curl dpkg-dev binutils cmake xxd
fi

for command in "$C_COMPILER" "$CXX_COMPILER" curl dpkg-deb readelf ninja python3; do
    require_command "$command"
done
for directory in "$GCC_INCLUDE_DIR" "$CXX_INCLUDE_DIR" \
    "$CXX_INCLUDE_DIR/aarch64-linux-gnu" "$CXX_INCLUDE_DIR/backward"; do
    [[ -d "$directory" ]] || {
        printf 'Missing GCC 10 cross header directory: %s\n' "$directory" >&2
        exit 1
    }
done

mkdir -p "$CACHE_DIR" "$TOOLS_DIR" "$STUB_DIR"
if [[ ! -x "$VENV_DIR/bin/meson" ]]; then
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install meson
fi

if [[ ! -f "$SYSROOT/lib/aarch64-linux-gnu/libc-2.28.so" || \
      ! -f "$SYSROOT/usr/include/stdlib.h" || \
      ! -f "$SYSROOT/usr/include/aarch64-linux-gnu/bits/libc-header-start.h" || \
      ! -f "$SYSROOT/usr/include/linux/limits.h" || \
      ! -f "$SYSROOT/usr/lib/aarch64-linux-gnu/libstdc++.so.6" || \
      ! -f "$SYSROOT/lib/aarch64-linux-gnu/libgcc_s.so.1" || \
      ! -f "$SYSROOT/.apotris-gcc-runtime-10.2.1-6" ]]; then
    printf '%s\n' 'Preparing the local aarch64 GLIBC 2.28 compatibility sysroot...'
    mkdir -p "$SYSROOT"

    for package in libc6 libc6-dev; do
        deb="$(fetch_deb 'https://archive.debian.org/debian/pool/main/g/glibc' "${package}_2.28-10+deb10u1_arm64.deb")"
        dpkg-deb --extract "$deb" "$SYSROOT"
    done

    deb="$(fetch_deb 'https://archive.debian.org/debian/pool/main/l/linux' 'linux-libc-dev_4.19.249-2_arm64.deb')"
    dpkg-deb --extract "$deb" "$SYSROOT"

    for package in libstdc++6_10.2.1-6_arm64.deb libgcc-s1_10.2.1-6_arm64.deb; do
        deb="$(fetch_deb 'https://archive.debian.org/debian/pool/main/g/gcc-10' "$package")"
        dpkg-deb --extract "$deb" "$SYSROOT"
    done
    : > "$SYSROOT/.apotris-gcc-runtime-10.2.1-6"

    # Debian development links are absolute in the package but must be local
    # after extraction to a standalone sysroot.
    for link in "$SYSROOT"/usr/lib/aarch64-linux-gnu/*.so; do
        target="$(readlink "$link" || true)"
        case "$target" in
            /lib/*) ln -sfn "../../../${target#/}" "$link" ;;
        esac
    done
fi

# Meson discards the compiler's implicit include directories. Copy them under
# the cache so their C++-then-sysroot order is explicit and reproducible.
if [[ ! -f "$CXX_OVERLAY_DIR/cstddef" || \
      ! -f "$CXX_OVERLAY_DIR/aarch64-linux-gnu/bits/c++config.h" ]]; then
    rm -rf "$CXX_OVERLAY_DIR"
    mkdir -p "$CXX_OVERLAY_DIR"
    cp -a "$CXX_INCLUDE_DIR/." "$CXX_OVERLAY_DIR/"
fi

# These optional pthread clock APIs are advertised by Ubuntu's headers but do
# not exist in the GLIBC 2.28 baseline.
sed -i -E \
    '/^#define _GLIBCXX_USE_PTHREAD_(COND_CLOCKWAIT|MUTEX_CLOCKLOCK|RWLOCK_CLOCKLOCK) 1$/d' \
    "$CXX_OVERLAY_DIR/aarch64-linux-gnu/bits/c++config.h"

if [[ ! -f "$STUB_DIR/libGLESv2.so" ]]; then
    printf '%s\n' 'Creating the aarch64 GLES link stub...'
    printf '%s\n' 'void apotris_gles_link_stub(void) {}' |
        "$C_COMPILER" --sysroot="$SYSROOT" \
            -B"$SYSROOT/usr/lib/aarch64-linux-gnu" -shared -fPIC -x c - \
            -Wl,-soname,libGLESv2.so.2 -o "$STUB_DIR/libGLESv2.so"
fi

for path in \
    "$VENV_DIR/bin/meson" \
    "$SYSROOT/lib/aarch64-linux-gnu/libc-2.28.so" \
    "$SYSROOT/usr/include/linux/limits.h" \
    "$SYSROOT/usr/lib/aarch64-linux-gnu/libstdc++.so.6" \
    "$SYSROOT/lib/aarch64-linux-gnu/libgcc_s.so.1" \
    "$SYSROOT/usr/lib/aarch64-linux-gnu/libpthread.so" \
    "$CXX_OVERLAY_DIR/cstddef" \
    "$STUB_DIR/libGLESv2.so"; do
    [[ -e "$path" ]] || {
        printf 'Incomplete toolchain environment: %s\n' "$path" >&2
        exit 1
    }
done

printf 'GCC=%s\nSYSROOT=glibc-2.28\nRUNTIME=gcc-10.2.1-6\n' "$($C_COMPILER -dumpversion)" > "$READY_FILE"
printf 'Toolchain ready: %s\n' "$READY_FILE"
