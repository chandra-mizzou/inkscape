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
# Prefer v4.4.3 on Ubuntu 22.04 if present (latest AppImage needs GLIBC 2.36+)
if [[ -z "${QGC_APPIMAGE:-}" ]]; then
  if [[ -f "${HOME}/QGroundControl-v4.4.3.AppImage" ]]; then
    export QGC_APPIMAGE="${HOME}/QGroundControl-v4.4.3.AppImage"
  else
    export QGC_APPIMAGE="${HOME}/QGroundControl.AppImage"
  fi
fi
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

# Gazebo transport — force localhost (avoids empty bridges / disc-zmq warnings)
export GZ_IP="${GZ_IP:-127.0.0.1}"

# Gazebo sensor topic stems (PX4 x500_mono_cam uses sensor/camera/ on many builds;
# older trees used sensor/imager/ — T4 auto-discovers either)
export GZ_IMAGE_TOPIC="${GZ_IMAGE_TOPIC:-/world/${GZ_WORLD_NAME}/model/${GZ_MODEL_NAME}/link/camera_link/sensor/camera/image}"
export GZ_CAMERA_INFO_TOPIC="${GZ_CAMERA_INFO_TOPIC:-/world/${GZ_WORLD_NAME}/model/${GZ_MODEL_NAME}/link/camera_link/sensor/camera/camera_info}"
export GZ_IMU_TOPIC="${GZ_IMU_TOPIC:-/world/${GZ_WORLD_NAME}/model/${GZ_MODEL_NAME}/link/base_link/sensor/imu_sensor/imu}"

# ROS topics expected by VINS-Fusion
export ROS_IMAGE_TOPIC="${ROS_IMAGE_TOPIC:-/cam0/image_raw}"
export ROS_CAMERA_INFO_TOPIC="${ROS_CAMERA_INFO_TOPIC:-/cam0/camera_info}"
export ROS_IMU_TOPIC="${ROS_IMU_TOPIC:-/imu0}"

# Micro XRCE-DDS Agent
export XRCE_PORT="${XRCE_PORT:-8888}"

# Terminal emulator preference (gnome-terminal | tmux | xterm)
export TERM_BACKEND="${TERM_BACKEND:-auto}"

# ---------------------------------------------------------------------------
# Safely source ament/ROS setup scripts under `set -u`.
# ROS setup.bash references optional vars (e.g. AMENT_TRACE_SETUP_FILES)
# that are unbound by default and trip nounset.
# ---------------------------------------------------------------------------
vins_source_ros_setup() {
  local setup_file="$1"
  if [[ ! -f "${setup_file}" ]]; then
    return 1
  fi
  # Pre-define optional ament vars so older/newer setups are both happy
  export AMENT_TRACE_SETUP_FILES="${AMENT_TRACE_SETUP_FILES:-}"
  export AMENT_PYTHON_EXECUTABLE="${AMENT_PYTHON_EXECUTABLE:-}"
  export COLCON_TRACE="${COLCON_TRACE:-}"
  export COLCON_PYTHON_EXECUTABLE="${COLCON_PYTHON_EXECUTABLE:-}"
  export AMENT_PREFIX_PATH="${AMENT_PREFIX_PATH:-}"
  export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}"
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
  export PATH="${PATH:-}"
  export PYTHONPATH="${PYTHONPATH:-}"

  local _nounset_was_on=0
  if [[ $- == *u* ]]; then
    _nounset_was_on=1
    set +u
  fi
  # shellcheck disable=SC1090
  source "${setup_file}"
  if [[ "${_nounset_was_on}" -eq 1 ]]; then
    set -u
  fi
  return 0
}

# Source ROS 2 if available
vins_source_ros_setup "/opt/ros/${ROS_DISTRO}/setup.bash" || true

# Source workspace overlays if built
vins_source_ros_setup "${ROS2_WS}/install/setup.bash" || true

mkdir -p "${OUTPUT_DIR}"
