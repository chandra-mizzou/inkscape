#!/usr/bin/env bash
# T2 — QGroundControl
# Finds AppImage under $HOME even if not marked executable / slightly renamed.
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T2] Starting QGroundControl"
echo "     Looking for AppImage (QGC_APPIMAGE=${QGC_APPIMAGE})"
echo "     Waiting a few seconds so PX4 SITL can bind UDP 14550..."
sleep 5

# Clear Snap GTK pollution that can break AppImage/GUI launch from VS Code terminals
unset GTK_PATH GIO_MODULE_DIR GDK_PIXBUF_MODULE_FILE || true

find_qgc() {
  local candidate
  local candidates=(
    "${QGC_APPIMAGE}"
    "${HOME}/QGroundControl.AppImage"
    "${HOME}/QGroundControl-x86_64.AppImage"
    "${HOME}/Downloads/QGroundControl.AppImage"
    "${HOME}/Downloads/QGroundControl-x86_64.AppImage"
    "${HOME}/Desktop/QGroundControl.AppImage"
    "${HOME}/Applications/QGroundControl.AppImage"
    "/opt/QGroundControl/QGroundControl.AppImage"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  candidate="$(find "${HOME}" -maxdepth 3 -type f -iname 'QGroundControl*.AppImage' 2>/dev/null | head -n1 || true)"
  if [[ -n "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi
  return 1
}

# 1) PATH binary
if command -v QGroundControl >/dev/null 2>&1; then
  echo "[T2] Using QGroundControl from PATH: $(command -v QGroundControl)"
  exec QGroundControl
fi

# 2) AppImage (configured path or discovered)
if QGC_PATH="$(find_qgc)"; then
  export QGC_APPIMAGE="${QGC_PATH}"
  echo "[T2] Found: ${QGC_PATH}"
  ls -la "${QGC_PATH}"

  if [[ ! -x "${QGC_PATH}" ]]; then
    echo "[T2] Not executable — running: chmod +x \"${QGC_PATH}\""
    chmod +x "${QGC_PATH}"
  fi

  # FUSE is often missing/blocked; extract-and-run is more reliable
  if [[ "${QGC_FORCE_EXTRACT:-0}" == "1" ]] || ! lsmod 2>/dev/null | grep -q fuse; then
    echo "[T2] Launching with --appimage-extract-and-run (no/blocked FUSE or forced)"
    exec "${QGC_PATH}" --appimage-extract-and-run
  fi

  echo "[T2] Launching AppImage..."
  exec "${QGC_PATH}"
fi

# 3) Flatpak
if command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -qi qgroundcontrol; then
  echo "[T2] Using Flatpak QGroundControl"
  exec flatpak run org.mavlink.qgroundcontrol
fi

# 4) lowercase binary name
if command -v qgroundcontrol >/dev/null 2>&1; then
  exec qgroundcontrol
fi

echo "ERROR: QGroundControl not found."
echo ""
echo "Checked:"
echo "  ${QGC_APPIMAGE}"
echo "  ${HOME}/QGroundControl.AppImage"
echo "  ${HOME}/Downloads/QGroundControl*.AppImage"
echo ""
echo "If the file exists under another name:"
echo "  ls -la \$HOME/*QGround* \$HOME/Downloads/*QGround* 2>/dev/null"
echo "  export QGC_APPIMAGE=/exact/path/to/file.AppImage"
echo "  chmod +x \"\$QGC_APPIMAGE\""
echo "  ./scripts/02_qgroundcontrol.sh"
echo ""
echo "Or relaunch with:  ./scripts/run_vins_fusion_sim.sh --tmux --no-qgc"
ls -la "${HOME}/QGroundControl"* "${HOME}/Downloads/QGroundControl"* 2>/dev/null || true
exit 1
