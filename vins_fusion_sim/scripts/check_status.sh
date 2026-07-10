#!/usr/bin/env bash
# Live health check for the VINS-Fusion VIO simulation stack.
# Run in a free terminal while the sim is up:
#   ./scripts/check_status.sh
#   ./scripts/check_status.sh --watch
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

WATCH=0
[[ "${1:-}" == "--watch" ]] && WATCH=1

check_once() {
  echo "============================================================"
  echo " VINS-Fusion sim status  $(date +%H:%M:%S)"
  echo "============================================================"

  # Processes
  echo ""
  echo "[processes]"
  for pat in "px4|bin/px4" "gz sim|ruby" "MicroXRCEAgent" "ros_gz_bridge" "vins" "loop_fusion" "QGroundControl" "rviz2" "vins_to_px4"; do
    if pgrep -af "$pat" >/dev/null 2>&1; then
      echo "  OK   $pat"
    else
      echo "  --   $pat  (not running)"
    fi
  done

  # tmux
  echo ""
  echo "[tmux]"
  if command -v tmux >/dev/null 2>&1 && tmux has-session -t "=vins-fusion-vio" 2>/dev/null; then
    echo "  OK   session vins-fusion-vio"
    tmux list-windows -t vins-fusion-vio -F '       #{window_index}: #{window_name}  (#{window_active_clients} viewers)' 2>/dev/null || true
    echo "  Attach: tmux attach -t vins-fusion-vio"
    echo "  Switch: Ctrl-b then 0..8   (or n / p)"
  else
    echo "  --   no tmux session vins-fusion-vio"
  fi

  # Gazebo topics
  echo ""
  echo "[gazebo topics]"
  if command -v gz >/dev/null 2>&1; then
    local imgs imus
    imgs="$(gz topic -l 2>/dev/null | grep -E '/image$' | head -n 5 || true)"
    imus="$(gz topic -l 2>/dev/null | grep -E '/imu$' | head -n 5 || true)"
    if [[ -n "${imgs}" ]]; then
      echo "  image:"
      echo "${imgs}" | sed 's/^/    /'
    else
      echo "  --   no Gazebo image topics yet (is T1 / Gazebo up?)"
    fi
    if [[ -n "${imus}" ]]; then
      echo "  imu:"
      echo "${imus}" | sed 's/^/    /'
    else
      echo "  --   no Gazebo imu topics yet"
    fi
  else
    echo "  --   gz CLI not found"
  fi

  # ROS topics
  echo ""
  echo "[ros2 topics]"
  if command -v ros2 >/dev/null 2>&1; then
    for t in "${ROS_IMAGE_TOPIC}" "${ROS_IMU_TOPIC}" /odometry /vins_estimator/odometry /image_track /fmu/in/vehicle_visual_odometry; do
      if timeout 2 ros2 topic list 2>/dev/null | grep -qx "$t"; then
        rate="$(timeout 3 ros2 topic hz "$t" 2>/dev/null | awk '/average rate/{print $3; exit}' || true)"
        if [[ -n "${rate}" ]]; then
          echo "  OK   $t   (~${rate} Hz)"
        else
          echo "  ..   $t   (exists, no samples in 3s)"
        fi
      else
        echo "  --   $t"
      fi
    done
  else
    echo "  --   ros2 not in PATH (source scripts/source_env.sh)"
  fi

  echo ""
  echo "[what to do next]"
  echo "  1. In tmux, check windows T3/T4/T6 for errors (Ctrl-b then number)."
  echo "  2. In QGroundControl: wait for vehicle ready → Arm → Takeoff ~3 m."
  echo "  3. Fly a slow figure-8. VINS needs motion; hover alone looks idle."
  echo "  4. In RViz, set Fixed Frame to 'world' or 'odom' and enable Path/Odometry."
  echo "============================================================"
}

if [[ "${WATCH}" -eq 1 ]]; then
  while true; do
    clear 2>/dev/null || true
    check_once
    sleep 5
  done
else
  check_once
fi
