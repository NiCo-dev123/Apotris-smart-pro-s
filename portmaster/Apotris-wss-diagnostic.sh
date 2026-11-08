#!/bin/bash
# Temporary WSS diagnostic for the Apotris online-porting milestone.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
GAMEDIR="$SCRIPT_DIR/apotris-wss-diagnostic"
LOGFILE="$SCRIPT_DIR/Apotris-wss-diagnostic.log"

exec > "$LOGFILE" 2>&1
echo "=== Apotris WSS diagnostic: $(date) ==="
echo "Kernel: $(uname -a 2>/dev/null || echo unavailable)"
cd "$GAMEDIR" || exit 1
./apotris-wss-diagnostic
status=$?
echo "=== WSS diagnostic exited: $status ==="
echo "Copy this file from Roms/ports: $LOGFILE"
exit "$status"
