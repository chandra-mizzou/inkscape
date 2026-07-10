#!/usr/bin/env bash
# T1 — PX4 SITL + Gazebo Harmonic GUI (mono-camera X500)
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

export GZ_IP="${GZ_IP:-127.0.0.1}"

# GUI must be enabled — HEADLESS=1 / STANDALONE blocks the Gazebo window
unset HEADLESS
unset PX4_GZ_STANDALONE

# Snap/VS Code env pollution breaks Gazebo OpenGL/GUI
unset GTK_PATH GIO_MODULE_DIR GDK_PIXBUF_MODULE_FILE GDK_PIXBUF_MODULEDIR || true

if [[ -z "${DISPLAY:-}" ]]; then
  if [[ -S /tmp/.X11-unix/X0 ]]; then
    export DISPLAY=:0
  else
    echo "[T1] ERROR: DISPLAY is not set — Gazebo GUI cannot open."
    echo "     Open a desktop terminal and run:  export DISPLAY=:0"
    exit 1
  fi
fi

MAKE_TARGET="${PX4_SIM_MODEL}"
case "${MAKE_TARGET}" in
  gz_*) ;;
  *) MAKE_TARGET="gz_${MAKE_TARGET}" ;;
esac

echo "[T1] Starting PX4 SITL + Gazebo GUI"
echo "     target   = ${MAKE_TARGET}"
echo "     PX4_DIR  = ${PX4_DIR}"
echo "     DISPLAY  = ${DISPLAY}"
echo "     GZ_IP    = ${GZ_IP}"
echo "     HEADLESS = <unset>"

if [[ ! -d "${PX4_DIR}" ]]; then
  echo "[T1] ERROR: PX4_DIR does not exist: ${PX4_DIR}"
  exit 1
fi

if ! command -v gz >/dev/null 2>&1; then
  echo "[T1] ERROR: 'gz' not found. Install Gazebo Harmonic:"
  echo "     sudo apt install gz-harmonic"
  exit 1
fi

cd "${PX4_DIR}"

# Resource paths for PX4 Gazebo models/worlds
if [[ -f "build/px4_sitl_default/rootfs/gz_env.sh" ]]; then
  # shellcheck disable=SC1091
  set +u
  source "build/px4_sitl_default/rootfs/gz_env.sh" || true
  set -e
  echo "[T1] sourced gz_env.sh"
fi
if [[ -f "Tools/simulation/gz/setup_gz.bash" ]]; then
  # shellcheck disable=SC1091
  set +u
  source "Tools/simulation/gz/setup_gz.bash" || true
  set -e
  echo "[T1] sourced setup_gz.bash"
fi

export PX4_SYS_AUTOSTART PX4_GZ_WORLD PX4_GZ_MODEL_POSE GZ_IP DISPLAY
export PX4_SIM_MODEL="${MAKE_TARGET}"

echo "[T1] Running: make px4_sitl ${MAKE_TARGET}"
echo "[T1] Watch this tab for errors. Gazebo window should open shortly."
echo "[T1] Manual GUI test:  gz sim -v 4 empty.sdf"

if [[ ! -f Makefile ]]; then
  echo "[T1] ERROR: no Makefile in ${PX4_DIR}"
  exit 1
fi

# Keep process in foreground so the tab shows PX4 + gz logs
exec make px4_sitl "${MAKE_TARGET}"
