#!/usr/bin/env bash
# Source ROS 2 + the VINS workspace, with clear errors if they are missing.
#
# Usage:
#   source /path/to/vins_fusion_sim/scripts/source_env.sh
#
# Do NOT run this with `bash scripts/source_env.sh` — exports would be lost.
# Always use:  source scripts/source_env.sh

_VINS_SOURCE_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_VINS_SOURCE_ENV_DIR}/../config/env.sh"

_ok=1

if vins_source_ros_setup "/opt/ros/${ROS_DISTRO}/setup.bash"; then
  echo "[ok] sourced /opt/ros/${ROS_DISTRO}/setup.bash"
else
  echo "[missing] ROS 2 (${ROS_DISTRO}) not installed at /opt/ros/${ROS_DISTRO}/"
  echo "          Fix:  cd ${_VINS_SOURCE_ENV_DIR}/.. && ./scripts/setup_all.sh --yes"
  _ok=0
fi

if vins_source_ros_setup "${ROS2_WS}/install/setup.bash"; then
  echo "[ok] sourced ${ROS2_WS}/install/setup.bash"
else
  echo "[missing] ${ROS2_WS}/install/setup.bash"
  echo ""
  echo "  That file is created only AFTER the ROS 2 workspace is built."
  echo "  It does not exist until you run the installer (or colcon build)."
  echo ""
  echo "  Fix (recommended — installs + builds everything):"
  echo "    cd ${_VINS_SOURCE_ENV_DIR}/.."
  echo "    ./scripts/setup_all.sh --yes"
  echo "    source ${_VINS_SOURCE_ENV_DIR}/source_env.sh"
  echo ""
  echo "  Or, if sources are already in ${ROS2_WS}/src:"
  echo "    source /opt/ros/${ROS_DISTRO}/setup.bash"
  echo "    cd ${ROS2_WS} && colcon build --symlink-install"
  echo "    source ${ROS2_WS}/install/setup.bash"
  echo ""
  _ok=0
fi

if [[ "${_ok}" -eq 1 ]]; then
  echo "[ok] environment ready  (ROS2_WS=${ROS2_WS}  PX4_DIR=${PX4_DIR})"
else
  echo "[fail] environment incomplete — run setup_all.sh before launching the sim."
  # When sourced, return; when executed, exit
  return 1 2>/dev/null || exit 1
fi
