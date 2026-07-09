#!/usr/bin/env bash
# T2 — QGroundControl
# Ubuntu 22.04 (GLIBC 2.35) cannot run the newest "latest"/v5 AppImage (needs 2.36+).
# Prefer QGC v4.4.3 on hosts with GLIBC < 2.36.
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

QGC_COMPAT_URL="${QGC_COMPAT_URL:-https://github.com/mavlink/qgroundcontrol/releases/download/v4.4.3/QGroundControl.AppImage}"
QGC_COMPAT_PATH="${QGC_COMPAT_PATH:-$HOME/QGroundControl-v4.4.3.AppImage}"

echo "[T2] Starting QGroundControl"
echo "     Waiting a few seconds so PX4 SITL can bind UDP 14550..."
sleep 5

unset GTK_PATH GIO_MODULE_DIR GDK_PIXBUF_MODULE_FILE || true

host_glibc() {
  ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+$' || echo "0.0"
}

# True when host GLIBC is older than 2.36 (Ubuntu 22.04 = 2.35)
needs_compat_qgc() {
  local v
  v="$(host_glibc)"
  awk -v a="$v" 'BEGIN{split(a,p,"."); exit !((p[1]<2) || (p[1]==2 && p[2]<36))}'
}

download_compat_qgc() {
  echo "[T2] Downloading Ubuntu 22.04-compatible QGC v4.4.3"
  echo "     -> ${QGC_COMPAT_PATH}"
  echo "     URL: ${QGC_COMPAT_URL}"
  if command -v wget >/dev/null 2>&1; then
    wget -O "${QGC_COMPAT_PATH}" "${QGC_COMPAT_URL}"
  else
    curl -fL -o "${QGC_COMPAT_PATH}" "${QGC_COMPAT_URL}"
  fi
  chmod +x "${QGC_COMPAT_PATH}"
}

ensure_executable() {
  local app="$1"
  if [[ ! -x "${app}" ]]; then
    echo "[T2] chmod +x \"${app}\""
    chmod +x "${app}"
  fi
}

# 1) PATH binary
if command -v QGroundControl >/dev/null 2>&1; then
  echo "[T2] Using QGroundControl from PATH: $(command -v QGroundControl)"
  exec QGroundControl
fi

# 2) On Ubuntu 22.04 / old GLIBC: use v4.4.3 (not cloudfront "latest")
if needs_compat_qgc; then
  echo "[T2] Host GLIBC $(host_glibc) < 2.36 — using QGC v4.4.3 (22.04-compatible)"
  if [[ ! -f "${QGC_COMPAT_PATH}" ]]; then
    download_compat_qgc
  fi
  ensure_executable "${QGC_COMPAT_PATH}"
  export QGC_APPIMAGE="${QGC_COMPAT_PATH}"
  echo "[T2] Launching ${QGC_APPIMAGE}"
  if [[ "${QGC_FORCE_EXTRACT:-0}" == "1" ]]; then
    exec "${QGC_APPIMAGE}" --appimage-extract-and-run
  fi
  exec "${QGC_APPIMAGE}"
fi

# 3) Newer host: try configured / common AppImage paths
for candidate in \
  "${QGC_APPIMAGE}" \
  "${QGC_COMPAT_PATH}" \
  "${HOME}/QGroundControl.AppImage" \
  "${HOME}/QGroundControl-x86_64.AppImage" \
  "${HOME}/Downloads/QGroundControl.AppImage"
do
  if [[ -f "${candidate}" ]]; then
    ensure_executable "${candidate}"
    export QGC_APPIMAGE="${candidate}"
    echo "[T2] Launching ${QGC_APPIMAGE}"
    if [[ "${QGC_FORCE_EXTRACT:-0}" == "1" ]]; then
      exec "${QGC_APPIMAGE}" --appimage-extract-and-run
    fi
    exec "${QGC_APPIMAGE}"
  fi
done

# 4) Flatpak
if command -v flatpak >/dev/null 2>&1; then
  if flatpak list 2>/dev/null | grep -qi qgroundcontrol; then
    echo "[T2] Using Flatpak QGroundControl"
    exec flatpak run org.mavlink.qgroundcontrol
  fi
  echo "[T2] Tip: flatpak install flathub org.mavlink.qgroundcontrol"
fi

echo "ERROR: QGroundControl not found / not runnable."
echo ""
echo "Your 'latest' AppImage needs GLIBC 2.36+ (Ubuntu 24.04)."
echo "On Ubuntu 22.04 install QGC v4.4.3 instead:"
echo "  wget -O \$HOME/QGroundControl-v4.4.3.AppImage \\"
echo "    ${QGC_COMPAT_URL}"
echo "  chmod +x \$HOME/QGroundControl-v4.4.3.AppImage"
echo "  export QGC_APPIMAGE=\$HOME/QGroundControl-v4.4.3.AppImage"
echo "  ./scripts/02_qgroundcontrol.sh"
echo ""
echo "Or skip QGC: ./scripts/run_vins_fusion_sim.sh --tmux --no-qgc"
echo "  (fly with ./scripts/10_demo_takeoff.sh)"
exit 1
