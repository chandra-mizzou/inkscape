#!/usr/bin/env bash
# T1 — PX4 SITL + Gazebo Harmonic with mono-camera X500
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

export GZ_IP="${GZ_IP:-127.0.0.1}"

echo "[T1] Starting PX4 SITL + Gazebo (${PX4_SIM_MODEL})"
echo "     PX4_DIR=${PX4_DIR}"
echo "     GZ_IP=${GZ_IP}"

if [[ ! -d "${PX4_DIR}" ]]; then
  echo "ERROR: PX4_DIR does not exist: ${PX4_DIR}"
  exit 1
fi

cd "${PX4_DIR}"

if [[ -f "Makefile" ]]; then
  export PX4_SYS_AUTOSTART
  export PX4_GZ_WORLD
  export PX4_GZ_MODEL_POSE
  export GZ_IP
  echo "[T1] make px4_sitl ${PX4_SIM_MODEL}"
  echo "[T1] Tip: if camera topics stay empty, unpause Gazebo (play button)."
  exec make px4_sitl "${PX4_SIM_MODEL}"
fi

BIN="${PX4_DIR}/build/px4_sitl_default/bin/px4"
if [[ -x "${BIN}" ]]; then
  export PX4_SYS_AUTOSTART PX4_SIM_MODEL PX4_GZ_WORLD PX4_GZ_MODEL_POSE GZ_IP
  exec "${BIN}"
fi

echo "ERROR: Could not find PX4 build. Run: cd ${PX4_DIR} && make px4_sitl"
exit 1
