#!/usr/bin/env bash
# T4 — Bridge Gazebo camera + IMU topics into ROS 2
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T4] ros_gz_bridge — Gazebo -> ROS 2"
echo "     image : ${GZ_IMAGE_TOPIC}"
echo "     imu   : ${GZ_IMU_TOPIC}"
echo "     Waiting for Gazebo topics..."
sleep 12

# Discover actual topics if the default model name differs
if command -v gz >/dev/null 2>&1; then
  echo "[T4] Available Gazebo image/imu topics:"
  gz topic -l 2>/dev/null | grep -E 'image$|/imu$' || true
fi

BRIDGE_YAML="${VINS_SIM_DIR}/config/ros_gz_bridge.yaml"

# Prefer YAML config (cleaner remapping). Fall back to CLI args.
if [[ -f "${BRIDGE_YAML}" ]] && ros2 pkg prefix ros_gz_bridge >/dev/null 2>&1; then
  echo "[T4] Using bridge config: ${BRIDGE_YAML}"
  # Generate runtime YAML with expanded topic names
  RUNTIME_YAML="$(mktemp /tmp/ros_gz_bridge_XXXX.yaml)"
  sed \
    -e "s|__GZ_IMAGE_TOPIC__|${GZ_IMAGE_TOPIC}|g" \
    -e "s|__GZ_CAMERA_INFO_TOPIC__|${GZ_CAMERA_INFO_TOPIC}|g" \
    -e "s|__GZ_IMU_TOPIC__|${GZ_IMU_TOPIC}|g" \
    -e "s|__ROS_IMAGE_TOPIC__|${ROS_IMAGE_TOPIC}|g" \
    -e "s|__ROS_CAMERA_INFO_TOPIC__|${ROS_CAMERA_INFO_TOPIC}|g" \
    -e "s|__ROS_IMU_TOPIC__|${ROS_IMU_TOPIC}|g" \
    "${BRIDGE_YAML}" > "${RUNTIME_YAML}"
  echo "[T4] Runtime bridge file:"
  cat "${RUNTIME_YAML}"
  exec ros2 run ros_gz_bridge parameter_bridge --ros-args -p "config_file:=${RUNTIME_YAML}"
fi

# CLI fallback (keeps Gazebo topic names on ROS side; remapper handles rename)
echo "[T4] YAML bridge unavailable — using CLI parameter_bridge"
exec ros2 run ros_gz_bridge parameter_bridge \
  "${GZ_IMAGE_TOPIC}@sensor_msgs/msg/Image@gz.msgs.Image" \
  "${GZ_CAMERA_INFO_TOPIC}@sensor_msgs/msg/CameraInfo@gz.msgs.CameraInfo" \
  "${GZ_IMU_TOPIC}@sensor_msgs/msg/Imu@gz.msgs.IMU"
