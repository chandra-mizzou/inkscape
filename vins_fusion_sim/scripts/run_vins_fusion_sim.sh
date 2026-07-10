#!/usr/bin/env bash
# =============================================================================
# VINS-Fusion VIO launcher — ONE terminal window with sub-panes / tabs
# =============================================================================
# Default: tmux session with a tiled pane grid (all modules visible together).
# Optional: gnome-terminal tabs in a single window.
#
# Usage:
#   ./scripts/run_vins_fusion_sim.sh              # tmux panes (default)
#   ./scripts/run_vins_fusion_sim.sh --tabs       # gnome-terminal tabs
#   ./scripts/run_vins_fusion_sim.sh --windows    # old: one tmux window each
#   ./scripts/run_vins_fusion_sim.sh --dry-run
#   ./scripts/run_vins_fusion_sim.sh --no-qgc
#   ./scripts/run_vins_fusion_sim.sh --no-rviz
#   ./scripts/run_vins_fusion_sim.sh --no-loop
# =============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

# Prefer localhost Gazebo transport (fixes disc-zmq / empty bridge topics)
export GZ_IP="${GZ_IP:-127.0.0.1}"

DRY_RUN=0
SKIP_QGC=0
SKIP_RVIZ=0
SKIP_LOOP=0
LAYOUT="${LAYOUT:-panes}"   # panes | tabs | windows | sequential

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --tmux|--panes) LAYOUT=panes ;;
    --tabs) LAYOUT=tabs ;;
    --windows) LAYOUT=windows ;;
    --sequential) LAYOUT=sequential ;;
    --no-qgc) SKIP_QGC=1 ;;
    --no-rviz) SKIP_RVIZ=1 ;;
    --no-loop) SKIP_LOOP=1 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

sanitize_snap_env() {
  unset GTK_PATH || true
  unset GIO_MODULE_DIR || true
  unset GDK_PIXBUF_MODULE_FILE || true
  unset GDK_PIXBUF_MODULEDIR || true
  if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
    local cleaned="" part
    IFS=':' read -ra _ld_parts <<< "${LD_LIBRARY_PATH}"
    for part in "${_ld_parts[@]}"; do
      [[ -z "${part}" ]] && continue
      [[ "${part}" == /snap/* ]] && continue
      if [[ -z "${cleaned}" ]]; then cleaned="${part}"; else cleaned="${cleaned}:${part}"; fi
    done
    export LD_LIBRARY_PATH="${cleaned}"
  fi
}

sanitize_snap_env

SESSION_NAME="vins-fusion-vio"
LOG_DIR="${VINS_SIM_DIR}/logs"
mkdir -p "${LOG_DIR}"

declare -a TITLES=()
declare -a CMDS=()

add_term() {
  TITLES+=("$1")
  CMDS+=("$2")
}

# ---------------------------------------------------------------------------
# Module list
# ---------------------------------------------------------------------------
add_term "T1-PX4-Gazebo" "bash '${SCRIPT_DIR}/01_px4_sitl.sh'"
if [[ "${SKIP_QGC}" -eq 0 ]]; then
  add_term "T2-QGC" "bash '${SCRIPT_DIR}/02_qgroundcontrol.sh'"
fi
add_term "T3-XRCE" "bash '${SCRIPT_DIR}/03_micro_xrce_agent.sh'"
add_term "T4-gz-bridge" "bash '${SCRIPT_DIR}/04_ros_gz_bridge.sh'"
add_term "T5-topics" "bash '${SCRIPT_DIR}/05_topic_remap.sh'"
add_term "T6-VINS" "bash '${SCRIPT_DIR}/06_vins_fusion.sh'"
if [[ "${SKIP_LOOP}" -eq 0 ]]; then
  add_term "T7-loop" "bash '${SCRIPT_DIR}/07_loop_fusion.sh'"
fi
add_term "T8-vins2px4" "bash '${SCRIPT_DIR}/08_vins_to_px4.sh'"
if [[ "${SKIP_RVIZ}" -eq 0 ]]; then
  add_term "T9-RViz" "bash '${SCRIPT_DIR}/09_rviz.sh'"
fi

pane_cmd() {
  # Keep pane open after exit; export GZ_IP into the child shell
  printf "export GZ_IP=%q; bash -lc %q; echo; echo '[%s] exited — Ctrl-b d to detach'; bash" \
    "${GZ_IP}" \
    "${1}; echo; echo '[exited]'; bash" \
    "${2}"
}

print_plan() {
  echo "============================================================"
  echo " VINS-Fusion VIO — single-window subterminal launch"
  echo "============================================================"
  echo " Layout      : ${LAYOUT}   (panes=tmux grid, tabs=gnome tabs)"
  echo " GZ_IP       : ${GZ_IP}"
  echo " PX4_DIR     : ${PX4_DIR}"
  echo " ROS2_WS     : ${ROS2_WS}"
  echo " Model       : ${PX4_SIM_MODEL} (${GZ_MODEL_NAME})"
  echo " VINS config : ${VINS_CONFIG}"
  echo "------------------------------------------------------------"
  local i
  for i in "${!TITLES[@]}"; do
    printf "  [%d] %-16s %s\n" "$((i + 1))" "${TITLES[$i]}" "${CMDS[$i]}"
  done
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# tmux: ONE window, tiled panes (default)
# ---------------------------------------------------------------------------
launch_tmux_panes() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux not found. Install: sudo apt install tmux" >&2
    exit 1
  fi
  tmux has-session -t "=${SESSION_NAME}" 2>/dev/null && tmux kill-session -t "${SESSION_NAME}"

  local first_cmd
  first_cmd="export GZ_IP=${GZ_IP}; ${CMDS[0]}; echo; echo '[${TITLES[0]}] exited'; bash"
  tmux new-session -d -s "${SESSION_NAME}" -n "vio" \
    "bash -lc $(printf '%q' "${first_cmd}")"

  local i
  for ((i = 1; i < ${#TITLES[@]}; i++)); do
    local cmd
    cmd="export GZ_IP=${GZ_IP}; ${CMDS[$i]}; echo; echo '[${TITLES[$i]}] exited'; bash"
    # Alternate split direction for a usable grid
    if (( i % 2 == 1 )); then
      tmux split-window -t "${SESSION_NAME}:vio" -h "bash -lc $(printf '%q' "${cmd}")"
    else
      tmux split-window -t "${SESSION_NAME}:vio" -v "bash -lc $(printf '%q' "${cmd}")"
    fi
    tmux select-layout -t "${SESSION_NAME}:vio" tiled >/dev/null
    sleep 0.25
  done

  tmux select-layout -t "${SESSION_NAME}:vio" tiled
  # Label panes with titles (tmux 2.6+)
  for i in "${!TITLES[@]}"; do
    tmux select-pane -t "${SESSION_NAME}:vio.${i}" -T "${TITLES[$i]}" 2>/dev/null || true
  done
  tmux set-option -t "${SESSION_NAME}" pane-border-status top 2>/dev/null || true
  tmux set-option -t "${SESSION_NAME}" pane-border-format " #{pane_index}:#{pane_title} " 2>/dev/null || true
  tmux select-pane -t "${SESSION_NAME}:vio.0"

  echo ""
  echo "tmux session '${SESSION_NAME}' — ONE window with ${#TITLES[@]} panes."
  echo "  Attach     : tmux attach -t ${SESSION_NAME}"
  echo "  Move focus : Ctrl-b then arrow keys"
  echo "  Zoom pane  : Ctrl-b then z"
  echo "  Detach     : Ctrl-b then d"
  echo "  Kill       : tmux kill-session -t ${SESSION_NAME}"
  echo "  Status     : ${SCRIPT_DIR}/check_status.sh"
  if [[ -t 0 ]]; then
    tmux attach -t "${SESSION_NAME}"
  fi
}

# ---------------------------------------------------------------------------
# tmux: separate windows (legacy)
# ---------------------------------------------------------------------------
launch_tmux_windows() {
  tmux has-session -t "=${SESSION_NAME}" 2>/dev/null && tmux kill-session -t "${SESSION_NAME}"
  local cmd0="export GZ_IP=${GZ_IP}; ${CMDS[0]}; echo; echo '[${TITLES[0]}] exited'; bash"
  tmux new-session -d -s "${SESSION_NAME}" -n "${TITLES[0]}" "bash -lc $(printf '%q' "${cmd0}")"
  local i
  for ((i = 1; i < ${#TITLES[@]}; i++)); do
    local cmd="export GZ_IP=${GZ_IP}; ${CMDS[$i]}; echo; echo '[${TITLES[$i]}] exited'; bash"
    tmux new-window -t "${SESSION_NAME}" -n "${TITLES[$i]}" "bash -lc $(printf '%q' "${cmd}")"
    sleep 0.2
  done
  tmux select-window -t "${SESSION_NAME}:0"
  echo "tmux windows mode — switch with Ctrl-b n / p"
  [[ -t 0 ]] && tmux attach -t "${SESSION_NAME}"
}

# ---------------------------------------------------------------------------
# gnome-terminal: ONE window, many tabs
# ---------------------------------------------------------------------------
launch_gnome_tabs() {
  sanitize_snap_env
  if ! command -v gnome-terminal >/dev/null 2>&1; then
    echo "[WARN] gnome-terminal missing — falling back to tmux panes"
    launch_tmux_panes
    return
  fi
  local args=(--window)
  local i
  for i in "${!TITLES[@]}"; do
    local inner="export GZ_IP=${GZ_IP}; ${CMDS[$i]}; echo; echo '[${TITLES[$i]}] exited — press Enter'; read -r"
    args+=(--tab --title="${TITLES[$i]}" -- bash -lc "${inner}")
  done
  env -u GTK_PATH -u GIO_MODULE_DIR -u GDK_PIXBUF_MODULE_FILE \
    gnome-terminal "${args[@]}"
  echo "Opened ONE gnome-terminal window with ${#TITLES[@]} tabs."
}

launch_sequential() {
  echo "Background mode. Logs: ${LOG_DIR}/"
  local i
  for i in "${!TITLES[@]}"; do
    local logfile="${LOG_DIR}/${TITLES[$i]}.log"
    bash -lc "export GZ_IP=${GZ_IP}; ${CMDS[$i]}" >"${logfile}" 2>&1 &
    echo "  started ${TITLES[$i]} (pid=$!) -> ${logfile}"
    sleep 1
  done
}

preflight() {
  local warn=0
  [[ -d "${PX4_DIR}" ]] || { echo "[WARN] PX4_DIR missing: ${PX4_DIR}"; warn=1; }
  [[ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]] || { echo "[WARN] ROS 2 missing"; warn=1; }
  [[ -f "${VINS_CONFIG}" ]] || { echo "[WARN] VINS config missing"; warn=1; }
  if [[ "${warn}" -eq 1 ]]; then
    echo "Some prerequisites missing — panes will show the real errors."
  fi
  echo "[note] QGC 'Failed to fetch tile / Network not available' is normal offline — ignore."
  echo "[note] If /cam0 has no data: ensure Gazebo is unpaused and GZ_IP=${GZ_IP}."
}

print_plan
preflight

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "(dry-run) Nothing launched."
  exit 0
fi

case "${LAYOUT}" in
  panes) launch_tmux_panes ;;
  windows) launch_tmux_windows ;;
  tabs) launch_gnome_tabs ;;
  sequential) launch_sequential ;;
  *) echo "Unknown LAYOUT=${LAYOUT}" >&2; exit 1 ;;
esac

echo ""
echo "Next:"
echo "  1. In Gazebo: confirm sim is running (not paused)."
echo "  2. Check T4/T5 panes: ros2 topic hz /cam0/image_raw should show a rate."
echo "  3. QGC: Arm → Takeoff → slow figure-8 (map tile errors are OK offline)."
echo "  4. ${SCRIPT_DIR}/check_status.sh"
