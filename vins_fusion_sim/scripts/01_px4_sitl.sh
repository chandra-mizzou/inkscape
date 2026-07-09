#!/usr/bin/env bash
# T1 — PX4 SITL + Gazebo Harmonic with mono-camera X500
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T1] Starting PX4 SITL + Gazebo (${PX4_SIM_MODEL})"
echo "     PX4_DIR=${PX4_DIR}"

if [[ ! -d "${PX4_DIR}" ]]; then
  echo "ERROR: PX4_DIR does not exist: ${PX4_DIR}"
  echo "Clone with:"
  echo "  git clone https://github.com/PX4/PX4-Autopilot.git --recursive ${PX4_DIR}"
  echo "  bash ${PX4_DIR}/Tools/setup/ubuntu.sh"
  echo "  cd ${PX4_DIR} && make px4_sitl"
  exit 1
fi

cd "${PX4_DIR}"

# Prefer make target (builds if needed). Falls back to prebuilt binary.
if [[ -f "Makefile" ]]; then
  export PX4_SYS_AUTOSTART
  export PX4_GZ_WORLD
  export PX4_GZ_MODEL_POSE
  echo "[T1] make px4_sitl ${PX4_SIM_MODEL}"
  exec make px4_sitl "${PX4_SIM_MODEL}"
fi

BIN="${PX4_DIR}/build/px4_sitl_default/bin/px4"
if [[ -x "${BIN}" ]]; then
  export PX4_SYS_AUTOSTART
  export PX4_SIM_MODEL
  export PX4_GZ_WORLD
  export PX4_GZ_MODEL_POSE
  echo "[T1] launching prebuilt ${BIN}"
  exec "${BIN}"
fi

echo "ERROR: Could not find PX4 build. Run: cd ${PX4_DIR} && make px4_sitl"
exit 1
