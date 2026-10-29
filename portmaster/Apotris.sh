#!/bin/bash
# PORTMASTER: apotris.zip, Apotris.sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
GAMEDIR="$SCRIPT_DIR/apotris"
LOGFILE="$GAMEDIR/log.txt"

mkdir -p "$GAMEDIR/saves"
exec >> "$LOGFILE" 2>&1
echo "=== Apotris PortMaster: $(date) ==="

# Source optional PortMaster controller settings.  On the tested Spruce image,
# control.txt does not define get_controls; SDL's native controller discovery
# remains the supported fallback.
for control_file in \
    /mnt/SDCARD/spruce/portmaster/control.txt \
    /mnt/sdcard/spruce/portmaster/control.txt; do
    if [ -f "$control_file" ]; then
        # shellcheck source=/dev/null
        . "$control_file"
        if command -v get_controls >/dev/null 2>&1; then
            get_controls
        fi
        break
    fi
done

export HOME="$GAMEDIR/saves"
export XDG_CONFIG_HOME="$GAMEDIR/saves/config"
export XDG_DATA_HOME="$GAMEDIR/saves/data"
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"

# The validated SDL 2.32.6 runtime is bundled under the lowercase filename
# required by Apotris. Firmware supplies only the Mali/EGL/GLES driver chain.
export LD_LIBRARY_PATH="$GAMEDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$GAMEDIR" || exit 1
./Apotris "$@"
status=$?
echo "=== Apotris exited: $status ==="
exit "$status"
