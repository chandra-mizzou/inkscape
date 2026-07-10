#!/usr/bin/env bash
# T6 — VINS-Fusion visual-inertial odometry estimator
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T6] Starting VINS-Fusion"
echo "     config = ${VINS_CONFIG}"
echo "     Waiting for /cam0/image_raw and /imu0..."
sleep 16

# Wait until camera topic is alive (up to ~60s)
for i in $(seq 1 30); do
  if timeout 2 ros2 topic hz "${ROS_IMAGE_TOPIC}" 2>/dev/null | head -n1 | grep -q "average rate"; then
    echo "[T6] Camera topic is publishing."
    break
  fi
  echo "[T6] waiting for ${ROS_IMAGE_TOPIC}... (${i}/30)"
  sleep 2
done

if ! ros2 pkg list 2>/dev/null | grep -qx "vins"; then
  echo "ERROR: ROS 2 package 'vins' not found."
  echo "Build VINS-Fusion-ROS2 into ${ROS2_WS} (see README / setup_all.sh)."
  exit 1
fi

# Preferred: ros2 run vins vins_node <config>
if ros2 pkg executables vins 2>/dev/null | grep -q "vins_node\|vins"; then
  EXE="$(ros2 pkg executables vins 2>/dev/null | awk '{print $2}' | head -n1)"
  echo "[T6] ros2 run vins ${EXE} ${VINS_CONFIG}"
  exec ros2 run vins "${EXE}" "${VINS_CONFIG}"
fi

# Fallback launch file names used by various forks
for launch in vins_fusion_ros2.launch.py vins.launch.py; do
  if [[ -n "$(ros2 pkg prefix vins 2>/dev/null)" ]]; then
    if find "$(ros2 pkg prefix vins)/share" -name "${launch}" 2>/dev/null | grep -q .; then
      echo "[T6] ros2 launch vins ${launch}"
      exec ros2 launch vins "${launch}" config_file:="${VINS_CONFIG}"
    fi
  fi
done

# Last resort: common binary name from zinuok fork
echo "[T6] Trying: ros2 run vins vins ${VINS_CONFIG}"
exec ros2 run vins vins "${VINS_CONFIG}"
