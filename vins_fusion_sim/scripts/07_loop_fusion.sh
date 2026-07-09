#!/usr/bin/env bash
# T7 — VINS-Fusion loop closure / pose graph
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T7] Starting loop_fusion"
echo "     config = ${VINS_CONFIG}"
sleep 20

if ! ros2 pkg list 2>/dev/null | grep -Eq "^(loop_fusion|vins)$"; then
  echo "ERROR: loop_fusion / vins package not found in the ROS 2 workspace."
  exit 1
fi

# zinuok / HKUST style
if ros2 pkg list 2>/dev/null | grep -qx "loop_fusion"; then
  EXE="$(ros2 pkg executables loop_fusion 2>/dev/null | awk '{print $2}' | head -n1)"
  if [[ -n "${EXE}" ]]; then
    echo "[T7] ros2 run loop_fusion ${EXE} ${VINS_CONFIG}"
    exec ros2 run loop_fusion "${EXE}" "${VINS_CONFIG}"
  fi
  exec ros2 run loop_fusion loop_fusion_node "${VINS_CONFIG}"
fi

# Some forks ship loop fusion inside the vins package
if ros2 pkg executables vins 2>/dev/null | grep -qi loop; then
  EXE="$(ros2 pkg executables vins 2>/dev/null | awk '/loop/{print $2; exit}')"
  exec ros2 run vins "${EXE}" "${VINS_CONFIG}"
fi

echo "[T7] No loop_fusion executable found — skipping."
echo "     VIO will still run without loop closure."
exec sleep infinity
