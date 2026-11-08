#!/bin/bash
# Temporary hardware/network probe for the Apotris online-porting milestone.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LOGFILE="$SCRIPT_DIR/Apotris-network-diagnostic.log"
API_HOST="api.apotris.com"
STUN_HOST="stun.l.google.com"

exec > "$LOGFILE" 2>&1
echo "=== Apotris network diagnostic: $(date) ==="

run() {
    echo
    echo "\$ $*"
    "$@"
    status=$?
    echo "[exit $status]"
    return 0
}

have() {
    command -v "$1" >/dev/null 2>&1
}

echo "PATH=$PATH"
echo "Kernel: $(uname -a 2>/dev/null || echo unavailable)"

echo
echo "=== Network interfaces ==="
if have ip; then
    run ip address
    run ip route
elif have ifconfig; then
    run ifconfig -a
else
    echo "Neither ip nor ifconfig is available."
fi
[ -r /proc/net/wireless ] && run cat /proc/net/wireless
[ -r /proc/net/route ] && run cat /proc/net/route
[ -r /etc/resolv.conf ] && run cat /etc/resolv.conf

echo
echo "=== Available network clients ==="
for tool in getent nslookup curl wget busybox nc; do
    if have "$tool"; then
        echo "$tool: $(command -v "$tool")"
    else
        echo "$tool: unavailable"
    fi
done

echo
echo "=== DNS: $API_HOST ==="
if have getent; then
    run getent hosts "$API_HOST"
elif have nslookup; then
    run nslookup "$API_HOST"
elif have busybox; then
    run busybox nslookup "$API_HOST"
else
    echo "No DNS diagnostic command is available."
fi

echo
echo "=== HTTPS certificate-validated request ==="
if have curl; then
    # Deliberately no --insecure option: success is meaningful only with TLS
    # certificate validation enabled.
    run curl --fail --show-error --silent --location --connect-timeout 10 \
        --max-time 20 -D - "https://$API_HOST/v1/online-players"
elif have wget; then
    echo "wget is available; its TLS verification behavior must be confirmed from its output."
    run wget -S -O - --timeout=20 "https://$API_HOST/v1/online-players"
elif have busybox; then
    echo "BusyBox wget may not validate certificates; HTTPS cannot be confirmed here."
    run busybox wget -S -O - "https://$API_HOST/v1/online-players"
else
    echo "No HTTPS client is available."
fi

echo
echo "=== TCP and UDP reachability probes ==="
if have nc; then
    run nc -z -w 5 "$API_HOST" 443
    # UDP is connectionless: a successful nc exit code is not proof that STUN
    # works. A later libdatachannel/libjuice test is required.
    run nc -u -z -w 5 "$STUN_HOST" 19302
else
    echo "nc unavailable; TCP/UDP probe skipped."
fi

echo
echo "=== Diagnostic complete ==="
echo "Copy this file from Roms/ports: $LOGFILE"
