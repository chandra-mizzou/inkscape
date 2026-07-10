#!/usr/bin/env bash
# =============================================================================
# VINS-Fusion VIO launcher — ONE terminal window with TABS (not tiled panes)
# =============================================================================
# Default: gnome-terminal (or mate/xfce/konsole) tabs in a single window.
# Fallback: tmux windows (switch with Ctrl-b n / p) — never tiled panes.
#
# Usage:
#   ./scripts/run_vins_fusion_sim.sh              # tabs in one window
#   ./scripts/run_vins_fusion_sim.sh --tmux       # tmux windows (not panes)
#   ./scripts/run_vins_fusion_sim.sh --dry-run
#   ./scripts/run_vins_fusion_sim.sh --no-qgc
#   ./scripts/run_vins_fusion_sim.sh --no-rviz
#   ./scripts/run_vins_fusion_sim.sh --no-loop
# =============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

export GZ_IP="${GZ_IP:-127.0.0.1}"
# Never start Gazebo headless unless the user explicitly asks
unset HEADLESS || true
export HEADLESS="${HEADLESS:-}"

DRY_RUN=0
SKIP_QGC=0
SKIP_RVIZ=0
SKIP_LOOP=0
LAYOUT="${LAYOUT:-tabs}"   # tabs | tmux | sequential

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --tabs) LAYOUT=tabs ;;
    --tmux|--windows) LAYOUT=tmux ;;
    --panes)
      echo "[WARN] --panes disabled by request; using tabs instead."
      LAYOUT=tabs
      ;;
    --sequential) LAYOUT=sequential ;;
    --no-qgc) SKIP_QGC=1 ;;
    --no-rviz) SKIP_RVIZ=1 ;;
    --no-loop) SKIP_LOOP=1 ;;
    -h|--help)
      sed -n '2,18p' "$0"
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

# Ensure a display for Gazebo / QGC / RViz
if [[ -z "${DISPLAY:-}" ]]; then
  if [[ -S /tmp/.X11-unix/X0 ]]; then
    export DISPLAY=:0
    echo "[info] DISPLAY was unset — using DISPLAY=:0"
  else
    echo "[WARN] DISPLAY is unset and no X0 socket found. Gazebo GUI will not open."
    echo "       Run this from a desktop terminal, or: export DISPLAY=:0"
  fi
fi

SESSION_NAME="vins-fusion-vio"
LOG_DIR="${VINS_SIM_DIR}/logs"
mkdir -p "${LOG_DIR}"

declare -a TITLES=()
declare -a CMDS=()

add_term() {
  TITLES+=("$1")
  CMDS+=("$2")
}

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

wrap_cmd() {
  # Shared env for every tab
  printf 'export GZ_IP=%q; unset HEADLESS; export DISPLAY=%q; %s; echo; echo "[%s] exited — press Enter"; read -r' \
    "${GZ_IP}" "${DISPLAY:-:0}" "$1" "$2"
}

print_plan() {
  echo "============================================================"
  echo " VINS-Fusion VIO — ONE window, multiple TABS"
  echo "============================================================"
  echo " Layout      : ${LAYOUT}"
  echo " DISPLAY     : ${DISPLAY:-<unset>}"
  echo " GZ_IP       : ${GZ_IP}"
  echo " PX4_DIR     : ${PX4_DIR}"
  echo " ROS2_WS     : ${ROS2_WS}"
  echo " Model       : ${PX4_SIM_MODEL}"
  echo "------------------------------------------------------------"
  local i
  for i in "${!TITLES[@]}"; do
    printf "  [%d] %-16s %s\n" "$((i + 1))" "${TITLES[$i]}" "${CMDS[$i]}"
  done
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# gnome-terminal / mate-terminal / xfce4-terminal: ONE window, many tabs
# ---------------------------------------------------------------------------
launch_gui_tabs() {
  sanitize_snap_env
  local i inner
  local -a args=()

  if command -v gnome-terminal >/dev/null 2>&1 && gnome-terminal --version >/dev/null 2>&1; then
    # First --tab creates the single window; more --tab add tabs (no tiling).
    for i in "${!TITLES[@]}"; do
      inner="$(wrap_cmd "${CMDS[$i]}" "${TITLES[$i]}")"
      args+=(--tab --title="${TITLES[$i]}" -- bash -lc "${inner}")
    done
    echo "[launch] gnome-terminal — ${#TITLES[@]} tabs in ONE window"
    env -u GTK_PATH -u GIO_MODULE_DIR -u GDK_PIXBUF_MODULE_FILE \
      gnome-terminal "${args[@]}"
    return 0
  fi

  if command -v mate-terminal >/dev/null 2>&1; then
    for i in "${!TITLES[@]}"; do
      inner="$(wrap_cmd "${CMDS[$i]}" "${TITLES[$i]}")"
      args+=(--tab --title="${TITLES[$i]}" -- bash -lc "${inner}")
    done
    echo "[launch] mate-terminal — ${#TITLES[@]} tabs in ONE window"
    mate-terminal "${args[@]}"
    return 0
  fi

  if command -v xfce4-terminal >/dev/null 2>&1; then
    # xfce4-terminal: first tab opens window; --tab adds more
    inner0="$(wrap_cmd "${CMDS[0]}" "${TITLES[0]}")"
    args=(--hold --title="${TITLES[0]}" -e "bash -lc $(printf '%q' "${inner0}")")
    for ((i = 1; i < ${#TITLES[@]}; i++)); do
      inner="$(wrap_cmd "${CMDS[$i]}" "${TITLES[$i]}")"
      args+=(--tab --title="${TITLES[$i]}" -e "bash -lc $(printf '%q' "${inner}")")
    done
    echo "[launch] xfce4-terminal — ${#TITLES[@]} tabs in ONE window"
    xfce4-terminal "${args[@]}"
    return 0
  fi

  if command -v konsole >/dev/null 2>&1; then
    # Konsole: new-tab via -e is awkward; open first then tabs via qdbus is fragile.
    # Use --tabs-from-file instead.
    local tabs_file
    tabs_file="$(mktemp /tmp/vins_konsole_tabs_XXXX.tabs)"
    for i in "${!TITLES[@]}"; do
      inner="$(wrap_cmd "${CMDS[$i]}" "${TITLES[$i]}")"
      {
        echo "title: ${TITLES[$i]} ;; working-directory: ${PWD} ;; command: bash -lc $(printf '%q' "${inner}")"
      } >> "${tabs_file}"
    done
    echo "[launch] konsole — tabs from ${tabs_file}"
    konsole --tabs-from-file "${tabs_file}" &
    return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# tmux: separate WINDOWS (tab-like), never tiled panes
# ---------------------------------------------------------------------------
launch_tmux_windows() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux not found. Install: sudo apt install tmux" >&2
    exit 1
  fi
  tmux has-session -t "=${SESSION_NAME}" 2>/dev/null && tmux kill-session -t "${SESSION_NAME}"

  local cmd0
  cmd0="export GZ_IP=${GZ_IP}; unset HEADLESS; export DISPLAY=${DISPLAY:-:0}; ${CMDS[0]}; echo; echo '[${TITLES[0]}] exited'; bash"
  tmux new-session -d -s "${SESSION_NAME}" -n "${TITLES[0]}" "bash -lc $(printf '%q' "${cmd0}")"

  local i
  for ((i = 1; i < ${#TITLES[@]}; i++)); do
    local cmd
    cmd="export GZ_IP=${GZ_IP}; unset HEADLESS; export DISPLAY=${DISPLAY:-:0}; ${CMDS[$i]}; echo; echo '[${TITLES[$i]}] exited'; bash"
    tmux new-window -t "${SESSION_NAME}" -n "${TITLES[$i]}" "bash -lc $(printf '%q' "${cmd}")"
    sleep 0.2
  done
  tmux select-window -t "${SESSION_NAME}:0"

  echo ""
  echo "tmux session '${SESSION_NAME}' — ${#TITLES[@]} WINDOWS (not tiled)."
  echo "  Attach : tmux attach -t ${SESSION_NAME}"
  echo "  Next   : Ctrl-b n     Prev: Ctrl-b p     List: Ctrl-b w"
  echo "  Detach : Ctrl-b d"
  [[ -t 0 ]] && tmux attach -t "${SESSION_NAME}"
}

launch_sequential() {
  echo "Background mode. Logs: ${LOG_DIR}/"
  local i
  for i in "${!TITLES[@]}"; do
    local logfile="${LOG_DIR}/${TITLES[$i]}.log"
    bash -lc "export GZ_IP=${GZ_IP}; unset HEADLESS; export DISPLAY=${DISPLAY:-:0}; ${CMDS[$i]}" >"${logfile}" 2>&1 &
    echo "  started ${TITLES[$i]} (pid=$!) -> ${logfile}"
    sleep 1
  done
}

preflight() {
  echo "[preflight] DISPLAY=${DISPLAY:-<unset>}  GZ_IP=${GZ_IP}  HEADLESS=${HEADLESS:-<unset>}"
  if ! command -v gz >/dev/null 2>&1; then
    echo "[WARN] 'gz' CLI not in PATH — Gazebo Harmonic may not be installed."
  else
    echo "[preflight] gz: $(gz sim --versions 2>/dev/null | head -n1 || gz --version 2>/dev/null | head -n1 || echo present)"
  fi
  if [[ ! -d "${PX4_DIR}" ]]; then
    echo "[WARN] PX4_DIR missing: ${PX4_DIR}"
  fi
  # Kill stale sims that block a new Gazebo GUI
  if pgrep -af 'gz sim|bin/px4' >/dev/null 2>&1; then
    echo "[preflight] Stale px4/gz processes detected. Consider: ${SCRIPT_DIR}/stop_sim.sh"
  fi
}

print_plan
preflight

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "(dry-run) Nothing launched."
  exit 0
fi

case "${LAYOUT}" in
  tabs)
    if ! launch_gui_tabs; then
      echo "[WARN] No tab-capable GUI terminal found — falling back to tmux windows."
      launch_tmux_windows
    fi
    ;;
  tmux) launch_tmux_windows ;;
  sequential) launch_sequential ;;
  *) echo "Unknown LAYOUT=${LAYOUT}" >&2; exit 1 ;;
esac

echo ""
echo "Next:"
echo "  • Switch tabs in the single terminal window to see T1 (Gazebo) logs."
echo "  • If Gazebo GUI missing: read T1 tab errors; try: export DISPLAY=:0"
echo "  • ${SCRIPT_DIR}/check_status.sh"
