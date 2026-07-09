#!/usr/bin/env bash
# T5 — Remap long Gazebo ROS topic names to VINS-Fusion expected names
# Only needed when the YAML bridge did not already remap topics.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T5] Topic remapper / relay"
echo "     Waiting for bridged topics..."
sleep 14

# If YAML bridge already published /cam0/image_raw, just monitor and idle.
if timeout 5 ros2 topic list 2>/dev/null | grep -qx "${ROS_IMAGE_TOPIC}"; then
  echo "[T5] ${ROS_IMAGE_TOPIC} already present — remapper idle (bridge did the rename)."
  echo "[T5] Monitoring topic rates (Ctrl+C to stop)..."
  while true; do
    echo "---- $(date +%H:%M:%S) ----"
    timeout 3 ros2 topic hz "${ROS_IMAGE_TOPIC}" 2>/dev/null || echo "  ${ROS_IMAGE_TOPIC}: no data yet"
    timeout 3 ros2 topic hz "${ROS_IMU_TOPIC}" 2>/dev/null || echo "  ${ROS_IMU_TOPIC}: no data yet"
    sleep 5
  done
fi

echo "[T5] Starting Python remapper node..."
exec python3 "${VINS_SIM_DIR}/python/topic_remapper.py" \
  --image-in "${GZ_IMAGE_TOPIC}" \
  --imu-in "${GZ_IMU_TOPIC}" \
  --camera-info-in "${GZ_CAMERA_INFO_TOPIC}" \
  --image-out "${ROS_IMAGE_TOPIC}" \
  --imu-out "${ROS_IMU_TOPIC}" \
  --camera-info-out "${ROS_CAMERA_INFO_TOPIC}"
