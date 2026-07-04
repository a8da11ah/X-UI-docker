#!/bin/bash
# Runs once, on the container's first boot, as a systemd oneshot unit
# (x-ui-pro-install.service). Reads config from environment variables passed
# in via docker-compose's env_file, builds the x-ui-pro.sh CLI flags from
# them, and drops a marker file so re-creating the container doesn't
# re-run the full installer against already-provisioned services.
set -euo pipefail

MARKER=/etc/x-ui-pro/.installed
mkdir -p /etc/x-ui-pro

if [ -f "$MARKER" ]; then
    echo "[x-ui-pro] already installed, skipping."
    exit 0
fi

: "${SUBDOMAIN:?SUBDOMAIN env var is required and must already resolve to this host's public IP (used for the Let's Encrypt cert)}"
: "${XUI_VER:=v2.9.3}"
: "${PANEL:=1}"
: "${COUNTRY:=xx}"
: "${SECURE:=no}"
: "${CDN:=off}"
: "${RANDOM_TEMPLATE:=n}"

ARGS=(-panel "$PANEL" -xuiver "$XUI_VER" -cdn "$CDN" -secure "$SECURE" -country "$COUNTRY" -subdomain "$SUBDOMAIN" -RandomTemplate "$RANDOM_TEMPLATE")

# UFW is intentionally left off by default: Docker already restricts the host
# to the ports you publish in docker-compose.yml, and running ufw/iptables
# inside a container fights with Docker's own netfilter rules.
[ -n "${UFW:-}" ] && ARGS+=(-ufw "$UFW")
[ -n "${TOR_COUNTRY:-}" ] && ARGS+=(-TorCountry "$TOR_COUNTRY")
[ -n "${WARP_COUNTRY:-}" ] && ARGS+=(-WarpCfonCountry "$WARP_COUNTRY")
[ -n "${WARP_LIC_KEY:-}" ] && ARGS+=(-WarpLicKey "$WARP_LIC_KEY")

echo "[x-ui-pro] fetching installer..."
apt-get update -qq
wget -qO /tmp/x-ui-pro.sh "https://raw.githubusercontent.com/GFW4Fun/x-ui-pro/master/x-ui-pro.sh"
chmod +x /tmp/x-ui-pro.sh

echo "[x-ui-pro] running installer with: ${ARGS[*]}"
bash /tmp/x-ui-pro.sh "${ARGS[@]}"

touch "$MARKER"
echo "[x-ui-pro] install complete."
