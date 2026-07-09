#!/usr/bin/env bash
# T2 — QGroundControl
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T2] Starting QGroundControl"
echo "     Waiting a few seconds so PX4 SITL can bind UDP 14550..."
sleep 5

if [[ -x "${QGC_APPIMAGE}" ]]; then
  exec "${QGC_APPIMAGE}"
fi

if command -v QGroundControl >/dev/null 2>&1; then
  exec QGroundControl
fi

# Flatpak fallback
if command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -qi qgroundcontrol; then
  exec flatpak run org.mavlink.qgroundcontrol
fi

echo "ERROR: QGroundControl not found."
echo "Download AppImage:"
echo "  wget https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl.AppImage -O ${QGC_APPIMAGE}"
echo "  chmod +x ${QGC_APPIMAGE}"
echo "Or relaunch with --no-qgc"
exit 1
