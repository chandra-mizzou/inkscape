#!/usr/bin/env bash
# =============================================================================
# One-shot dependency installer for the VINS-Fusion VIO simulation stack.
# Target: Ubuntu 22.04 + ROS 2 Humble + Gazebo Harmonic + PX4 SITL
# =============================================================================
# Usage:
#   ./scripts/setup_all.sh              # full install (asks before sudo steps)
#   ./scripts/setup_all.sh --yes        # non-interactive apt where possible
#   ./scripts/setup_all.sh --python-only
# =============================================================================
# Note: do NOT enable `set -u` here. ROS setup.bash and many apt/helper
# scripts reference optional unset variables (e.g. AMENT_TRACE_SETUP_FILES).
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

YES_FLAG=""
PYTHON_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES_FLAG="-y" ;;
    --python-only) PYTHON_ONLY=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

APT() { sudo apt-get install ${YES_FLAG} "$@"; }

echo "============================================================"
echo " VINS-Fusion VIO sim — dependency setup"
echo " ROS_DISTRO=${ROS_DISTRO}  GZ_VERSION=${GZ_VERSION}"
echo " PX4_DIR=${PX4_DIR}"
echo " ROS2_WS=${ROS2_WS}"
echo "============================================================"

# ---------------------------------------------------------------------------
# Python requirements (always)
# ---------------------------------------------------------------------------
install_python() {
  echo "[1/6] Python packages (requirements.txt)"
  python3 -m pip install --upgrade pip setuptools wheel
  python3 -m pip install -r "${VINS_SIM_DIR}/requirements.txt"
}

if [[ "${PYTHON_ONLY}" -eq 1 ]]; then
  install_python
  echo "Done (python-only)."
  exit 0
fi

# ---------------------------------------------------------------------------
# System packages
# ---------------------------------------------------------------------------
echo "[2/6] System packages"
sudo apt-get update
APT \
  git wget curl build-essential cmake ninja-build pkg-config \
  python3-pip python3-venv python3-numpy python3-scipy \
  tmux gnome-terminal \
  libeigen3-dev libgoogle-glog-dev libsuitesparse-dev \
  libopencv-dev libboost-all-dev \
  libyaml-cpp-dev \
  geographiclib-tools \
  || true

# GeographicLib datasets (optional but useful)
if command -v geographiclib-get-geoids >/dev/null 2>&1; then
  sudo geographiclib-get-geoids egm96-5 || true
fi

# ---------------------------------------------------------------------------
# ROS 2 Humble
# ---------------------------------------------------------------------------
echo "[3/6] ROS 2 ${ROS_DISTRO}"
if [[ ! -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]]; then
  echo "ROS 2 ${ROS_DISTRO} not detected. Installing..."
  sudo apt-get install ${YES_FLAG} software-properties-common
  sudo add-apt-repository ${YES_FLAG} universe || true
  sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
    | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
  sudo apt-get update
  APT ros-${ROS_DISTRO}-desktop
fi

# ROS setup.bash is incompatible with `set -u` (AMENT_TRACE_SETUP_FILES etc.)
vins_source_ros_setup "/opt/ros/${ROS_DISTRO}/setup.bash"

APT \
  ros-${ROS_DISTRO}-cv-bridge \
  ros-${ROS_DISTRO}-image-transport \
  ros-${ROS_DISTRO}-tf2-ros \
  ros-${ROS_DISTRO}-tf2-geometry-msgs \
  ros-${ROS_DISTRO}-nav-msgs \
  ros-${ROS_DISTRO}-sensor-msgs \
  ros-${ROS_DISTRO}-geometry-msgs \
  ros-${ROS_DISTRO}-rviz2 \
  ros-${ROS_DISTRO}-rqt-image-view \
  ros-${ROS_DISTRO}-ros-gz \
  ros-${ROS_DISTRO}-ros-gz-bridge \
  ros-${ROS_DISTRO}-ros-gz-image \
  ros-${ROS_DISTRO}-ros-gz-sim \
  python3-colcon-common-extensions \
  python3-rosdep \
  || true

if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
  sudo rosdep init || true
fi
rosdep update || true

# ---------------------------------------------------------------------------
# Gazebo Harmonic (if not already via ros-gz)
# ---------------------------------------------------------------------------
echo "[4/6] Gazebo ${GZ_VERSION}"
if ! command -v gz >/dev/null 2>&1; then
  sudo curl https://packages.osrfoundation.org/gazebo.gpg \
    --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null
  sudo apt-get update
  APT gz-harmonic || APT gz-${GZ_VERSION} || true
fi

# ---------------------------------------------------------------------------
# PX4 Autopilot
# ---------------------------------------------------------------------------
echo "[5/6] PX4 Autopilot -> ${PX4_DIR}"
if [[ ! -d "${PX4_DIR}" ]]; then
  git clone https://github.com/PX4/PX4-Autopilot.git --recursive "${PX4_DIR}"
  bash "${PX4_DIR}/Tools/setup/ubuntu.sh" --no-sim-tools || bash "${PX4_DIR}/Tools/setup/ubuntu.sh" || true
fi
(
  cd "${PX4_DIR}"
  # Build SITL once so first launch is faster
  make px4_sitl || true
)

# ---------------------------------------------------------------------------
# Micro XRCE-DDS Agent
# ---------------------------------------------------------------------------
if ! command -v MicroXRCEAgent >/dev/null 2>&1; then
  echo "Building Micro-XRCE-DDS-Agent..."
  AGENT_DIR="${HOME}/Micro-XRCE-DDS-Agent"
  if [[ ! -d "${AGENT_DIR}" ]]; then
    git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git "${AGENT_DIR}"
  fi
  mkdir -p "${AGENT_DIR}/build"
  (
    cd "${AGENT_DIR}/build"
    cmake ..
    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
  )
fi

# ---------------------------------------------------------------------------
# QGroundControl AppImage
# Use v4.4.3 on Ubuntu 22.04 (GLIBC 2.35). Cloudfront "latest"/v5 needs GLIBC 2.36+.
# ---------------------------------------------------------------------------
QGC_COMPAT_URL="${QGC_COMPAT_URL:-https://github.com/mavlink/qgroundcontrol/releases/download/v4.4.3/QGroundControl.AppImage}"
QGC_COMPAT_PATH="${QGC_COMPAT_PATH:-$HOME/QGroundControl-v4.4.3.AppImage}"
_host_glibc="$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+$' || echo 0.0)"
_need_compat=0
awk -v a="${_host_glibc}" 'BEGIN{split(a,p,"."); exit !((p[1]<2) || (p[1]==2 && p[2]<36))}' && _need_compat=1 || true

if [[ "${_need_compat}" -eq 1 ]]; then
  echo "Host GLIBC ${_host_glibc} < 2.36 — installing QGC v4.4.3 (Ubuntu 22.04 compatible)"
  if [[ ! -x "${QGC_COMPAT_PATH}" ]]; then
    wget -O "${QGC_COMPAT_PATH}" "${QGC_COMPAT_URL}" || true
    chmod +x "${QGC_COMPAT_PATH}" || true
  fi
  export QGC_APPIMAGE="${QGC_COMPAT_PATH}"
elif [[ ! -x "${QGC_APPIMAGE}" ]]; then
  echo "Downloading QGroundControl AppImage -> ${QGC_APPIMAGE}"
  wget -O "${QGC_APPIMAGE}" \
    "https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl.AppImage" || true
  chmod +x "${QGC_APPIMAGE}" || true
fi

# ---------------------------------------------------------------------------
# ROS 2 workspace: px4_msgs + VINS-Fusion-ROS2 + Ceres
# ---------------------------------------------------------------------------
echo "[6/6] ROS 2 workspace ${ROS2_WS}"
mkdir -p "${ROS2_WS}/src"
cd "${ROS2_WS}/src"

if [[ ! -d px4_msgs ]]; then
  git clone https://github.com/PX4/px4_msgs.git
fi

if [[ ! -d VINS-Fusion-ROS2 ]]; then
  # Community ROS 2 port (Humble-compatible)
  git clone https://github.com/zinuok/VINS-Fusion-ROS2.git || \
    git clone https://github.com/JanekDev/VINS-Fusion-ROS2-humble.git VINS-Fusion-ROS2
fi

# Disable GPU mode if the fork enables it by default (avoids CUDA OpenCV requirement)
FEATURE_H="$(find VINS-Fusion-ROS2 -path '*/feature_tracker.h' 2>/dev/null | head -n1 || true)"
if [[ -n "${FEATURE_H}" ]]; then
  sed -i 's|^#define GPU_MODE 1|// #define GPU_MODE 1|' "${FEATURE_H}" || true
fi

# Ceres Solver (required by VINS-Fusion)
if ! pkg-config --exists ceres 2>/dev/null && [[ ! -f /usr/local/lib/cmake/Ceres/CeresConfig.cmake ]]; then
  echo "Installing Ceres Solver 2.1.0 from source..."
  CERES_DIR="${HOME}/ceres-solver"
  if [[ ! -d "${CERES_DIR}" ]]; then
    git clone https://github.com/ceres-solver/ceres-solver.git "${CERES_DIR}"
    (
      cd "${CERES_DIR}"
      git checkout 2.1.0
      mkdir -p build && cd build
      cmake .. -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF
      make -j"$(nproc)"
      sudo make install
      sudo ldconfig
    )
  fi
fi

install_python

cd "${ROS2_WS}"
rosdep install --from-paths src --ignore-src -r ${YES_FLAG:- -y} || true
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release || {
  echo "[WARN] colcon build reported errors. Fix compile issues, then:"
  echo "  cd ${ROS2_WS} && colcon build --symlink-install"
}

# Symlink this package's config into a convenient place
mkdir -p "${OUTPUT_DIR}"
# Point VINS output_path at a real directory
sed -i "s|output_path: \".*\"|output_path: \"${OUTPUT_DIR}/\"|" \
  "${VINS_SIM_DIR}/config/gazebo_mono_imu_config.yaml" || true
sed -i "s|pose_graph_save_path: \".*\"|pose_graph_save_path: \"${OUTPUT_DIR}/pose_graph/\"|" \
  "${VINS_SIM_DIR}/config/gazebo_mono_imu_config.yaml" || true

# Make scripts executable
chmod +x "${VINS_SIM_DIR}/scripts/"*.sh
chmod +x "${VINS_SIM_DIR}/python/"*.py

echo ""
echo "============================================================"
echo " Setup finished."
echo " Add to ~/.bashrc:"
echo "   source /opt/ros/${ROS_DISTRO}/setup.bash"
echo "   source ${ROS2_WS}/install/setup.bash"
echo "   export PX4_DIR=${PX4_DIR}"
echo "   export ROS2_WS=${ROS2_WS}"
echo ""
echo " Launch simulation:"
echo "   ${VINS_SIM_DIR}/scripts/run_vins_fusion_sim.sh"
echo "   # or headless/SSH:  TERM_BACKEND=tmux ${VINS_SIM_DIR}/scripts/run_vins_fusion_sim.sh --tmux"
echo "============================================================"
