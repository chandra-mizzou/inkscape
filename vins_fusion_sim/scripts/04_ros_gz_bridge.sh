#!/usr/bin/env bash
# T4 — Bridge Gazebo camera + IMU topics into ROS 2
# Auto-discovers Gazebo topic names (model instance suffixes vary),
# then writes a runtime YAML that remaps onto /cam0/image_raw and /imu0.
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T4] ros_gz_bridge — Gazebo -> ROS 2"
echo "     default image : ${GZ_IMAGE_TOPIC}"
echo "     default imu   : ${GZ_IMU_TOPIC}"

wait_for_gz_topics() {
  local i found_img="" found_imu=""
  for i in $(seq 1 60); do
    if ! command -v gz >/dev/null 2>&1; then
      echo "[T4] gz CLI not found yet (${i}/60)..."
      sleep 2
      continue
    fi
    if gz topic -l 2>/dev/null | grep -qx "${GZ_IMAGE_TOPIC}"; then
      found_img="${GZ_IMAGE_TOPIC}"
    else
      found_img="$(gz topic -l 2>/dev/null | grep -E 'camera_link/.*/image$|/imager/image$|/IMX214/image$|/camera/image$' | head -n1 || true)"
    fi
    if gz topic -l 2>/dev/null | grep -qx "${GZ_IMU_TOPIC}"; then
      found_imu="${GZ_IMU_TOPIC}"
    else
      found_imu="$(gz topic -l 2>/dev/null | grep -E 'imu_sensor/imu$|base_link/.*/imu$' | head -n1 || true)"
    fi
    if [[ -n "${found_img}" && -n "${found_imu}" ]]; then
      GZ_IMAGE_TOPIC="${found_img}"
      GZ_IMU_TOPIC="${found_imu}"
      local info_guess="${GZ_IMAGE_TOPIC%/image}/camera_info"
      if gz topic -l 2>/dev/null | grep -qx "${info_guess}"; then
        GZ_CAMERA_INFO_TOPIC="${info_guess}"
      else
        GZ_CAMERA_INFO_TOPIC="$(gz topic -l 2>/dev/null | grep -E 'camera_info$' | head -n1 || true)"
      fi
      echo "[T4] Discovered topics:"
      echo "     image       = ${GZ_IMAGE_TOPIC}"
      echo "     camera_info = ${GZ_CAMERA_INFO_TOPIC:-<none>}"
      echo "     imu         = ${GZ_IMU_TOPIC}"
      return 0
    fi
    echo "[T4] waiting for Gazebo camera/IMU topics... (${i}/60)"
    if (( i % 10 == 0 )); then
      echo "[T4] currently available (image|imu):"
      gz topic -l 2>/dev/null | grep -Ei 'image$|/imu$' | sed 's/^/       /' || echo "       (none)"
    fi
    sleep 2
  done
  echo "[T4] ERROR: timed out waiting for Gazebo sensor topics."
  echo "     Is T1 (PX4 SITL / Gazebo) running with ${PX4_SIM_MODEL}?"
  echo "     Try: gz topic -l | grep -Ei 'image|imu'"
  return 1
}

wait_for_gz_topics || exit 1

if ! ros2 pkg prefix ros_gz_bridge >/dev/null 2>&1; then
  echo "[T4] ERROR: ros_gz_bridge package not found."
  echo "     Install: sudo apt install ros-${ROS_DISTRO}-ros-gz-bridge"
  exit 1
fi

RUNTIME_YAML="$(mktemp /tmp/ros_gz_bridge_XXXX.yaml)"
{
  cat <<EOF
- gz_topic_name: "${GZ_IMAGE_TOPIC}"
  ros_topic_name: "${ROS_IMAGE_TOPIC}"
  ros_type_name: "sensor_msgs/msg/Image"
  gz_type_name: "gz.msgs.Image"
  direction: GZ_TO_ROS
  lazy: false

- gz_topic_name: "${GZ_IMU_TOPIC}"
  ros_topic_name: "${ROS_IMU_TOPIC}"
  ros_type_name: "sensor_msgs/msg/Imu"
  gz_type_name: "gz.msgs.IMU"
  direction: GZ_TO_ROS
  lazy: false
EOF
  if [[ -n "${GZ_CAMERA_INFO_TOPIC:-}" ]]; then
    cat <<EOF

- gz_topic_name: "${GZ_CAMERA_INFO_TOPIC}"
  ros_topic_name: "${ROS_CAMERA_INFO_TOPIC}"
  ros_type_name: "sensor_msgs/msg/CameraInfo"
  gz_type_name: "gz.msgs.CameraInfo"
  direction: GZ_TO_ROS
  lazy: false
EOF
  fi
} > "${RUNTIME_YAML}"

echo "[T4] Runtime bridge config (${RUNTIME_YAML}):"
cat "${RUNTIME_YAML}"
echo "[T4] Publishing ROS topics: ${ROS_IMAGE_TOPIC} , ${ROS_IMU_TOPIC}"
echo "[T4] Verify with:  ros2 topic hz ${ROS_IMAGE_TOPIC}"

# Newer ros_gz_bridge: --ros-args -p config_file:=...
# Older: some builds accept the file differently — try primary first.
exec ros2 run ros_gz_bridge parameter_bridge --ros-args -p "config_file:=${RUNTIME_YAML}"
