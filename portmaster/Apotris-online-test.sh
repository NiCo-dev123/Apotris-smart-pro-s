#!/bin/bash
# Experimental online-profile launcher.  It is deliberately separate from
# Apotris.sh so the proven offline port remains available unchanged.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
GAMEDIR="$SCRIPT_DIR/apotris-online-test"
LOGFILE="$GAMEDIR/log.txt"

mkdir -p "$GAMEDIR/saves"
exec >> "$LOGFILE" 2>&1
echo "=== Apotris online test: $(date) ==="

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

if [ -r "$GAMEDIR/assets/ssl/cacert.pem" ]; then
    export CURL_CA_BUNDLE="$GAMEDIR/assets/ssl/cacert.pem"
    export SSL_CERT_FILE="$GAMEDIR/assets/ssl/cacert.pem"
else
    echo "Missing bundled CA certificate; refusing to start online test."
    exit 1
fi

export LD_LIBRARY_PATH="$GAMEDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$GAMEDIR" || exit 1
./Apotris "$@"
status=$?
echo "=== Apotris online test exited: $status ==="
exit "$status"
