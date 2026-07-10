#!/usr/bin/env bash
# T7 — VINS-Fusion loop closure / pose graph (optional)
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T7] Starting loop_fusion (optional)"
echo "     config = ${VINS_CONFIG}"
sleep 22

echo "[T7] ROS packages visible:"
ros2 pkg list 2>/dev/null | grep -Ei 'vins|loop' || echo "  (none matching vins/loop)"

if ros2 pkg list 2>/dev/null | grep -qx "loop_fusion"; then
  EXE="$(ros2 pkg executables loop_fusion 2>/dev/null | awk '{print $2}' | head -n1)"
  if [[ -n "${EXE}" ]]; then
    echo "[T7] ros2 run loop_fusion ${EXE} ${VINS_CONFIG}"
    exec ros2 run loop_fusion "${EXE}" "${VINS_CONFIG}"
  fi
  exec ros2 run loop_fusion loop_fusion_node "${VINS_CONFIG}"
fi

if ros2 pkg executables vins 2>/dev/null | grep -qi loop; then
  EXE="$(ros2 pkg executables vins 2>/dev/null | awk '/loop/{print $2; exit}')"
  echo "[T7] ros2 run vins ${EXE} ${VINS_CONFIG}"
  exec ros2 run vins "${EXE}" "${VINS_CONFIG}"
fi

echo "[T7] loop_fusion not installed — skipping (OK for mono VIO)."
echo "     T6 alone is enough. To enable later:"
echo "       cd ${ROS2_WS} && colcon list | grep -i loop"
echo "       colcon build --packages-select loop_fusion && source install/setup.bash"
echo "     This pane will idle."
exec sleep infinity
