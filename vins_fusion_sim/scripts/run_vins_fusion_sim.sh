#!/usr/bin/env bash
# =============================================================================
# Multi-terminal launcher for VINS-Fusion VIO on PX4 Gazebo SITL + QGC + ROS2
# =============================================================================
# Opens one terminal (or tmux pane) per process so you can watch logs live.
#
# Usage:
#   ./scripts/run_vins_fusion_sim.sh              # launch everything
#   ./scripts/run_vins_fusion_sim.sh --dry-run    # print commands only
#   ./scripts/run_vins_fusion_sim.sh --tmux       # force tmux backend
#   ./scripts/run_vins_fusion_sim.sh --no-qgc     # skip QGroundControl
#   ./scripts/run_vins_fusion_sim.sh --no-rviz    # skip RViz2
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

DRY_RUN=0
USE_TMUX=0
SKIP_QGC=0
SKIP_RVIZ=0
SKIP_LOOP=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --tmux) USE_TMUX=1; TERM_BACKEND=tmux ;;
    --no-qgc) SKIP_QGC=1 ;;
    --no-rviz) SKIP_RVIZ=1 ;;
    --no-loop) SKIP_LOOP=1 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Detect terminal backend
# ---------------------------------------------------------------------------
detect_backend() {
  if [[ "${TERM_BACKEND}" == "tmux" ]] || [[ "${USE_TMUX}" -eq 1 ]]; then
    echo "tmux"
    return
  fi
  if [[ "${TERM_BACKEND}" != "auto" ]]; then
    echo "${TERM_BACKEND}"
    return
  fi
  if command -v gnome-terminal >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    echo "gnome-terminal"
  elif command -v tmux >/dev/null 2>&1; then
    echo "tmux"
  elif command -v xterm >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    echo "xterm"
  else
    echo "sequential"
  fi
}

BACKEND="$(detect_backend)"
SESSION_NAME="vins-fusion-vio"
LOG_DIR="${VINS_SIM_DIR}/logs"
mkdir -p "${LOG_DIR}"

# Ordered list of (title, command) pairs
declare -a TITLES=()
declare -a CMDS=()

add_term() {
  TITLES+=("$1")
  CMDS+=("$2")
}

# ---------------------------------------------------------------------------
# Terminal definitions (order matters for startup dependencies)
# ---------------------------------------------------------------------------

# T1: PX4 SITL + Gazebo (spawns vehicle with mono camera)
add_term "T1-PX4-SITL-Gazebo" \
  "bash '${SCRIPT_DIR}/01_px4_sitl.sh'"

# T2: QGroundControl
if [[ "${SKIP_QGC}" -eq 0 ]]; then
  add_term "T2-QGroundControl" \
    "bash '${SCRIPT_DIR}/02_qgroundcontrol.sh'"
fi

# T3: Micro XRCE-DDS Agent (PX4 <-> ROS2)
add_term "T3-MicroXRCEAgent" \
  "bash '${SCRIPT_DIR}/03_micro_xrce_agent.sh'"

# T4: ros_gz_bridge (Gazebo camera + IMU -> ROS2)
add_term "T4-ros_gz_bridge" \
  "bash '${SCRIPT_DIR}/04_ros_gz_bridge.sh'"

# T5: Topic remapper (long Gazebo paths -> /cam0 /imu0)
add_term "T5-topic-remap" \
  "bash '${SCRIPT_DIR}/05_topic_remap.sh'"

# T6: VINS-Fusion estimator
add_term "T6-VINS-Fusion" \
  "bash '${SCRIPT_DIR}/06_vins_fusion.sh'"

# T7: Loop fusion (optional)
if [[ "${SKIP_LOOP}" -eq 0 ]]; then
  add_term "T7-loop-fusion" \
    "bash '${SCRIPT_DIR}/07_loop_fusion.sh'"
fi

# T8: VINS -> PX4 visual odometry bridge
add_term "T8-vins-to-px4" \
  "bash '${SCRIPT_DIR}/08_vins_to_px4.sh'"

# T9: RViz2
if [[ "${SKIP_RVIZ}" -eq 0 ]]; then
  add_term "T9-RViz2" \
    "bash '${SCRIPT_DIR}/09_rviz.sh'"
fi

# ---------------------------------------------------------------------------
# Launch helpers
# ---------------------------------------------------------------------------
print_plan() {
  echo "============================================================"
  echo " VINS-Fusion VIO Simulation — multi-terminal launch plan"
  echo "============================================================"
  echo " Backend     : ${BACKEND}"
  echo " PX4_DIR     : ${PX4_DIR}"
  echo " ROS2_WS     : ${ROS2_WS}"
  echo " Model       : ${PX4_SIM_MODEL} (${GZ_MODEL_NAME})"
  echo " VINS config : ${VINS_CONFIG}"
  echo " Output dir  : ${OUTPUT_DIR}"
  echo "------------------------------------------------------------"
  local i
  for i in "${!TITLES[@]}"; do
    printf "  [%d] %-22s %s\n" "$((i + 1))" "${TITLES[$i]}" "${CMDS[$i]}"
  done
  echo "============================================================"
}

launch_gnome() {
  local i
  for i in "${!TITLES[@]}"; do
    gnome-terminal --title="${TITLES[$i]}" -- bash -lc "${CMDS[$i]}; echo; echo '[${TITLES[$i]}] exited — press Enter'; read -r"
    sleep 0.4
  done
}

launch_xterm() {
  local i
  for i in "${!TITLES[@]}"; do
    xterm -T "${TITLES[$i]}" -e bash -lc "${CMDS[$i]}; echo; echo '[${TITLES[$i]}] exited — press Enter'; read -r" &
    sleep 0.4
  done
}

launch_tmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux not found. Install with: sudo apt install tmux" >&2
    exit 1
  fi
  # Kill previous session with same name if present
  tmux has-session -t "=${SESSION_NAME}" 2>/dev/null && tmux kill-session -t "${SESSION_NAME}"

  tmux new-session -d -s "${SESSION_NAME}" -n "${TITLES[0]}" \
    "bash -lc '${CMDS[0]}; echo; echo \"[${TITLES[0]}] exited\"; bash'"

  local i
  for ((i = 1; i < ${#TITLES[@]}; i++)); do
    tmux new-window -t "${SESSION_NAME}" -n "${TITLES[$i]}" \
      "bash -lc '${CMDS[$i]}; echo; echo \"[${TITLES[$i]}] exited\"; bash'"
    sleep 0.3
  done

  tmux select-window -t "${SESSION_NAME}:0"
  echo ""
  echo "tmux session '${SESSION_NAME}' started with ${#TITLES[@]} windows."
  echo "  Attach : tmux attach -t ${SESSION_NAME}"
  echo "  List   : tmux ls"
  echo "  Kill   : tmux kill-session -t ${SESSION_NAME}"
  if [[ -t 0 ]] && [[ -n "${DISPLAY:-}" || -n "${TMUX:-}" ]]; then
    tmux attach -t "${SESSION_NAME}"
  fi
}

launch_sequential() {
  echo "No GUI terminal / tmux available — running processes in background."
  echo "Logs: ${LOG_DIR}/"
  local i pid
  for i in "${!TITLES[@]}"; do
    local logfile="${LOG_DIR}/${TITLES[$i]}.log"
    bash -lc "${CMDS[$i]}" >"${logfile}" 2>&1 &
    pid=$!
    echo "  started ${TITLES[$i]} (pid=${pid}) -> ${logfile}"
    sleep 1
  done
  echo ""
  echo "All processes started. Tail a log with:"
  echo "  tail -f ${LOG_DIR}/T6-VINS-Fusion.log"
  echo "Stop all with:  pkill -f '01_px4_sitl|MicroXRCEAgent|vins|ros_gz_bridge' || true"
}

# ---------------------------------------------------------------------------
# Preflight checks (non-fatal warnings)
# ---------------------------------------------------------------------------
preflight() {
  local warn=0
  if [[ ! -d "${PX4_DIR}" ]]; then
    echo "[WARN] PX4_DIR not found: ${PX4_DIR}"
    echo "       Clone & build PX4 first (see README)."
    warn=1
  fi
  if [[ ! -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]]; then
    echo "[WARN] ROS 2 (${ROS_DISTRO}) not found under /opt/ros/"
    warn=1
  fi
  if [[ ! -f "${VINS_CONFIG}" ]]; then
    echo "[WARN] VINS config missing: ${VINS_CONFIG}"
    warn=1
  fi
  if [[ "${SKIP_QGC}" -eq 0 ]] && [[ ! -x "${QGC_APPIMAGE}" ]] && ! command -v QGroundControl >/dev/null 2>&1; then
    echo "[WARN] QGroundControl not found at ${QGC_APPIMAGE}"
    echo "       Download from https://qgroundcontrol.com/downloads/ or use --no-qgc"
    warn=1
  fi
  if [[ "${warn}" -eq 1 ]]; then
    echo ""
    echo "Some prerequisites are missing. Run ./scripts/setup_all.sh first."
    echo "Continuing anyway (terminals will show the real errors)..."
    echo ""
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
print_plan
preflight

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "(dry-run) Nothing launched."
  exit 0
fi

case "${BACKEND}" in
  gnome-terminal) launch_gnome ;;
  xterm)          launch_xterm ;;
  tmux)           launch_tmux ;;
  sequential)     launch_sequential ;;
  *)
    echo "Unsupported TERM_BACKEND=${BACKEND}" >&2
    exit 1
    ;;
esac

echo ""
echo "What to expect next:"
echo "  1. Gazebo opens with an X500 quadrotor + forward mono camera."
echo "  2. QGC connects to the SITL vehicle (UDP 14550)."
echo "  3. ros_gz_bridge remaps camera/IMU into /cam0/image_raw and /imu0."
echo "  4. VINS-Fusion starts tracking; RViz shows the path once you fly."
echo "  5. In QGC: arm, takeoff, and fly a slow figure-8 for best VIO."
echo ""
echo "Useful checks:"
echo "  ros2 topic hz /cam0/image_raw"
echo "  ros2 topic hz /imu0"
echo "  ros2 topic echo /odometry --once"
echo "  gz topic -l | grep -E 'image|imu'"
