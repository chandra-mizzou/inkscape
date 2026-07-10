#!/usr/bin/env bash
# T9 — RViz2 visualization for VINS path / tracked features
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T9] Starting RViz2"
sleep 24

RVIZ_CFG="${VINS_SIM_DIR}/config/vins_sim.rviz"

# Prefer package launch if present
if ros2 pkg list 2>/dev/null | grep -qx "vins"; then
  if find "$(ros2 pkg prefix vins)/share" -name 'vins_rviz.launch.xml' 2>/dev/null | grep -q .; then
    exec ros2 launch vins vins_rviz.launch.xml
  fi
fi

if [[ -f "${RVIZ_CFG}" ]]; then
  exec rviz2 -d "${RVIZ_CFG}"
fi

exec rviz2
