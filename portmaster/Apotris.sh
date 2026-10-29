#!/bin/bash
# PORTMASTER: apotris.zip, Apotris.sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
GAMEDIR="$SCRIPT_DIR/apotris"
LOGFILE="$GAMEDIR/log.txt"

mkdir -p "$GAMEDIR/saves"
exec >> "$LOGFILE" 2>&1
echo "=== Apotris PortMaster: $(date) ==="

report_elf_library() {
    library="$1"
    [ -f "$library" ] || return 0

    echo "--- ELF diagnostic: $library ---"
    if command -v file >/dev/null 2>&1; then
        file "$library" 2>&1
    fi

    # Spruce images differ: use the richest inspection utility present, then
    # always retain ldd's view of the dynamic-loader dependency graph.
    if command -v readelf >/dev/null 2>&1; then
        readelf -h "$library" 2>&1
        readelf -d "$library" 2>&1
    elif command -v objdump >/dev/null 2>&1; then
        objdump -p "$library" 2>&1
    elif command -v strings >/dev/null 2>&1; then
        echo "readelf/objdump unavailable; shared-object names visible in strings:"
        strings "$library" 2>&1 | grep -E '(^|/)lib[^/[:space:]]+\.so(\.[0-9]+)*$' | sort -u
    else
        echo "No ELF inspection utility available (readelf, objdump, strings)."
    fi

    if command -v ldd >/dev/null 2>&1; then
        echo "ldd:"
        ldd "$library" 2>&1 || true
    else
        echo "ldd unavailable."
    fi
}

report_runtime_libraries() {
    echo "=== Apotris firmware-library diagnostic ==="
    echo "PATH=$PATH"
    for library in \
        /usr/lib/libMali.so /usr/lib/libMali.so.* \
        /usr/lib/libmali.so /usr/lib/libmali.so.* \
        /usr/lib/libEGL.so /usr/lib/libEGL.so.* \
        /usr/lib/libGLESv2.so /usr/lib/libGLESv2.so.* \
        /usr/lib/libSDL2-2.0.so /usr/lib/libSDL2-2.0.so.* \
        /usr/lib/libSDL2.so /usr/lib/libSDL2.so.* \
        /lib/libEGL.so /lib/libEGL.so.* \
        /lib/libGLESv2.so /lib/libGLESv2.so.* \
        /lib/libSDL2-2.0.so /lib/libSDL2-2.0.so.* \
        /lib/libSDL2.so /lib/libSDL2.so.*; do
        report_elf_library "$library"
    done
    echo "=== End firmware-library diagnostic ==="
}

# Keep this enabled until the runtime library chain is validated on hardware.
report_runtime_libraries

# Spruce's PortMaster integration provides the normal controller mapping here.
for control_file in \
    /mnt/SDCARD/spruce/portmaster/control.txt \
    /mnt/sdcard/spruce/portmaster/control.txt; do
    if [ -f "$control_file" ]; then
        # shellcheck source=/dev/null
        . "$control_file"
        if command -v get_controls >/dev/null 2>&1; then
            get_controls
        else
            echo "Warning: $control_file does not define get_controls."
        fi
        break
    fi
done

export HOME="$GAMEDIR/saves"
export XDG_CONFIG_HOME="$GAMEDIR/saves/config"
export XDG_DATA_HOME="$GAMEDIR/saves/data"
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"

# Lot 1 hardware probe: the executable needs the historic lowercase
# `libsdl2.so`, while Spruce provides `libSDL2-2.0.so.0`.  A library-path
# change alone therefore kept loading the bundled SDL.  FAT/exFAT cannot make
# symbolic links, so copy the firmware SDL locally for this diagnostic only;
# it is created at launch and is never included in the ZIP.
SYSTEM_SDL=/usr/lib/libSDL2-2.0.so.0
SYSTEM_SDL_ALIAS_DIR="$GAMEDIR/.runtime-probe"
if [ -f "$SYSTEM_SDL" ] && mkdir -p "$SYSTEM_SDL_ALIAS_DIR" \
    && cp -f "$SYSTEM_SDL" "$SYSTEM_SDL_ALIAS_DIR/libsdl2.so"; then
    export LD_LIBRARY_PATH="$SYSTEM_SDL_ALIAS_DIR:/usr/lib:$GAMEDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    echo "SDL runtime probe: firmware SDL copy=$SYSTEM_SDL_ALIAS_DIR/libsdl2.so <- $SYSTEM_SDL"
else
    export LD_LIBRARY_PATH="$GAMEDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    echo "Warning: unable to prepare firmware SDL alias; using bundled SDL."
fi
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

cd "$GAMEDIR" || exit 1
./Apotris "$@"
status=$?
echo "=== Apotris exited: $status ==="
exit "$status"
