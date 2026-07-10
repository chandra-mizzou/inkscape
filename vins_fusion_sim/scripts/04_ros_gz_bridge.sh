#!/usr/bin/env bash
# T4 — Bridge Gazebo camera + IMU topics into ROS 2
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

export GZ_IP="${GZ_IP:-127.0.0.1}"

echo "[T4] ros_gz_bridge — Gazebo -> ROS 2"
echo "     GZ_IP=${GZ_IP}"
echo "     default image : ${GZ_IMAGE_TOPIC}"
echo "     default imu   : ${GZ_IMU_TOPIC}"

gz_topic_has_data() {
  local topic="$1"
  timeout 3 gz topic -e -t "${topic}" -n 1 >/dev/null 2>&1
}

wait_for_gz_topics() {
  local i found_img="" found_imu=""
  for i in $(seq 1 90); do
    if ! command -v gz >/dev/null 2>&1; then
      echo "[T4] gz CLI not found yet (${i}/90)..."
      sleep 2
      continue
    fi

    if gz topic -l 2>/dev/null | grep -qx "${GZ_IMAGE_TOPIC}"; then
      found_img="${GZ_IMAGE_TOPIC}"
    else
      found_img="$(gz topic -l 2>/dev/null | grep -E \
        'camera_link/sensor/(imager|camera)/image$|camera_link/.*/image$|/IMX214/image$' \
        | head -n1 || true)"
    fi
    if gz topic -l 2>/dev/null | grep -qx "${GZ_IMU_TOPIC}"; then
      found_imu="${GZ_IMU_TOPIC}"
    else
      found_imu="$(gz topic -l 2>/dev/null | grep -E \
        'imu_sensor/imu$|base_link/.*/imu$' \
        | head -n1 || true)"
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

      echo "[T4] Topics listed:"
      echo "     image       = ${GZ_IMAGE_TOPIC}"
      echo "     camera_info = ${GZ_CAMERA_INFO_TOPIC:-<none>}"
      echo "     imu         = ${GZ_IMU_TOPIC}"

      if gz_topic_has_data "${GZ_IMAGE_TOPIC}" && gz_topic_has_data "${GZ_IMU_TOPIC}"; then
        echo "[T4] Gazebo is publishing image + IMU samples."
        return 0
      fi
      echo "[T4] Topics exist but NO DATA yet — is Gazebo paused? (${i}/90)"
      echo "     Unpause Gazebo, or run:"
      echo "     gz service -s /world/${GZ_WORLD_NAME}/control --reqtype gz.msgs.WorldControl --reptype gz.msgs.Boolean --timeout 2000 --req 'pause: false'"
    else
      echo "[T4] waiting for Gazebo camera/IMU topic names... (${i}/90)"
    fi

    if (( i % 15 == 0 )); then
      echo "[T4] currently available (image|imu):"
      gz topic -l 2>/dev/null | grep -Ei 'image$|/imu$' | sed 's/^/       /' || echo "       (none)"
    fi
    sleep 2
  done
  echo "[T4] ERROR: timed out waiting for live Gazebo sensor data."
  return 1
}

wait_for_gz_topics || exit 1

if ! ros2 pkg prefix ros_gz_bridge >/dev/null 2>&1; then
  echo "[T4] ERROR: ros_gz_bridge not found. sudo apt install ros-${ROS_DISTRO}-ros-gz-bridge"
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

echo "[T4] Runtime bridge config:"
cat "${RUNTIME_YAML}"
echo "[T4] Verify after start:  ros2 topic hz ${ROS_IMAGE_TOPIC}"

exec env GZ_IP="${GZ_IP}" ros2 run ros_gz_bridge parameter_bridge \
  --ros-args -p "config_file:=${RUNTIME_YAML}"
