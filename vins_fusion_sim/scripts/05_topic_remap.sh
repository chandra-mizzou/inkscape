#!/usr/bin/env bash
# T5 — Confirm /cam0 and /imu0 exist; relay if the bridge kept long Gazebo names.
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T5] Topic remapper / monitor"
echo "     Waiting for bridged topics..."
sleep 8

for i in $(seq 1 45); do
  if timeout 2 ros2 topic list 2>/dev/null | grep -qx "${ROS_IMAGE_TOPIC}"; then
    echo "[T5] Found ${ROS_IMAGE_TOPIC}"
    break
  fi
  # If long Gazebo path appeared on ROS side, start remapper
  if timeout 2 ros2 topic list 2>/dev/null | grep -qx "${GZ_IMAGE_TOPIC}"; then
    echo "[T5] Bridge kept Gazebo topic names — starting remapper."
    exec python3 "${VINS_SIM_DIR}/python/topic_remapper.py" \
      --image-in "${GZ_IMAGE_TOPIC}" \
      --imu-in "${GZ_IMU_TOPIC}" \
      --camera-info-in "${GZ_CAMERA_INFO_TOPIC}" \
      --image-out "${ROS_IMAGE_TOPIC}" \
      --imu-out "${ROS_IMU_TOPIC}" \
      --camera-info-out "${ROS_CAMERA_INFO_TOPIC}"
  fi
  echo "[T5] waiting for camera topic... (${i}/45)"
  sleep 2
done

if ! timeout 2 ros2 topic list 2>/dev/null | grep -qx "${ROS_IMAGE_TOPIC}"; then
  echo "[T5] ERROR: ${ROS_IMAGE_TOPIC} never appeared."
  echo "     Check T4 (ros_gz_bridge) window for errors."
  echo "     gz topic -l | grep image"
  echo "     ros2 topic list | grep -i cam"
  exit 1
fi

echo "[T5] Monitoring rates (Ctrl+C to stop). Healthy: image ~10-30 Hz, imu ~100+ Hz"
while true; do
  echo "---- $(date +%H:%M:%S) ----"
  timeout 3 ros2 topic hz "${ROS_IMAGE_TOPIC}" 2>/dev/null | head -n 2 || echo "  ${ROS_IMAGE_TOPIC}: no data"
  timeout 3 ros2 topic hz "${ROS_IMU_TOPIC}" 2>/dev/null | head -n 2 || echo "  ${ROS_IMU_TOPIC}: no data"
  sleep 4
done
