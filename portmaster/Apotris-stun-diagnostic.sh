#!/bin/bash
# Temporary real-UDP ICE/STUN diagnostic for the Apotris online milestone.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
GAMEDIR="$SCRIPT_DIR/apotris-stun-diagnostic"
LOGFILE="$SCRIPT_DIR/Apotris-stun-diagnostic.log"

exec > "$LOGFILE" 2>&1
echo "=== Apotris STUN diagnostic: $(date) ==="
echo "Kernel: $(uname -a 2>/dev/null || echo unavailable)"
cd "$GAMEDIR" || exit 1
./apotris-stun-diagnostic
status=$?
echo "=== STUN diagnostic exited: $status ==="
echo "Copy this file from Roms/ports: $LOGFILE"
exit "$status"
