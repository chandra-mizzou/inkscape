#!/usr/bin/env bash
# Shared environment defaults for the VINS-Fusion VIO simulation stack.
# Override any variable before launching, e.g.:
#   export PX4_DIR=$HOME/PX4-Autopilot
#   export ROS_DISTRO=humble

# Resolve package root (vins_fusion_sim/)
_VINS_SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VINS_SIM_DIR="${VINS_SIM_DIR:-$_VINS_SIM_DIR}"

# --- Host paths (edit these to match your machine) ---
export PX4_DIR="${PX4_DIR:-$HOME/PX4-Autopilot}"
export QGC_APPIMAGE="${QGC_APPIMAGE:-$HOME/QGroundControl.AppImage}"
export ROS2_WS="${ROS2_WS:-$HOME/vins_ws}"
export VINS_CONFIG="${VINS_CONFIG:-$VINS_SIM_DIR/config/gazebo_mono_imu_config.yaml}"
export OUTPUT_DIR="${OUTPUT_DIR:-$HOME/vins_output}"

# --- ROS / Gazebo ---
export ROS_DISTRO="${ROS_DISTRO:-humble}"
export GZ_VERSION="${GZ_VERSION:-harmonic}"

# --- PX4 SITL model (mono camera + IMU) ---
# Alternatives: gz_x500_mono_cam_down, gz_x500_depth, gz_x500_vision
export PX4_SIM_MODEL="${PX4_SIM_MODEL:-gz_x500_mono_cam}"
export PX4_SYS_AUTOSTART="${PX4_SYS_AUTOSTART:-4010}"
export PX4_GZ_WORLD="${PX4_GZ_WORLD:-default}"
export PX4_GZ_MODEL_POSE="${PX4_GZ_MODEL_POSE:-0,0,0.1,0,0,0}"

# Model instance name used in Gazebo topic paths (usually <model>_0)
export GZ_MODEL_NAME="${GZ_MODEL_NAME:-x500_mono_cam_0}"
export GZ_WORLD_NAME="${GZ_WORLD_NAME:-default}"

# Gazebo sensor topic stems (verified against PX4 gz_x500_mono_cam)
export GZ_IMAGE_TOPIC="${GZ_IMAGE_TOPIC:-/world/${GZ_WORLD_NAME}/model/${GZ_MODEL_NAME}/link/camera_link/sensor/imager/image}"
export GZ_CAMERA_INFO_TOPIC="${GZ_CAMERA_INFO_TOPIC:-/world/${GZ_WORLD_NAME}/model/${GZ_MODEL_NAME}/link/camera_link/sensor/imager/camera_info}"
export GZ_IMU_TOPIC="${GZ_IMU_TOPIC:-/world/${GZ_WORLD_NAME}/model/${GZ_MODEL_NAME}/link/base_link/sensor/imu_sensor/imu}"

# ROS topics expected by VINS-Fusion
export ROS_IMAGE_TOPIC="${ROS_IMAGE_TOPIC:-/cam0/image_raw}"
export ROS_CAMERA_INFO_TOPIC="${ROS_CAMERA_INFO_TOPIC:-/cam0/camera_info}"
export ROS_IMU_TOPIC="${ROS_IMU_TOPIC:-/imu0}"

# Micro XRCE-DDS Agent
export XRCE_PORT="${XRCE_PORT:-8888}"

# Terminal emulator preference (gnome-terminal | tmux | xterm)
export TERM_BACKEND="${TERM_BACKEND:-auto}"

# Source ROS 2 if available
if [[ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]]; then
  # shellcheck disable=SC1090
  source "/opt/ros/${ROS_DISTRO}/setup.bash"
fi

# Source workspace overlays if built
if [[ -f "${ROS2_WS}/install/setup.bash" ]]; then
  # shellcheck disable=SC1090
  source "${ROS2_WS}/install/setup.bash"
fi

mkdir -p "${OUTPUT_DIR}"
