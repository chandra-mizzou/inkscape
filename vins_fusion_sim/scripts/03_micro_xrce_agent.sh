#!/usr/bin/env bash
# T3 — Micro XRCE-DDS Agent (bridges PX4 uORB <-> ROS 2 DDS)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T3] Starting MicroXRCEAgent on UDP port ${XRCE_PORT}"
echo "     Waiting for PX4 SITL..."
sleep 8

if ! command -v MicroXRCEAgent >/dev/null 2>&1; then
  echo "ERROR: MicroXRCEAgent not in PATH."
  echo "Install with:"
  echo "  git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git"
  echo "  cd Micro-XRCE-DDS-Agent && mkdir build && cd build"
  echo "  cmake .. && make -j\$(nproc) && sudo make install && sudo ldconfig"
  echo "Or: sudo snap install micro-xrce-dds-agent --edge   (if available)"
  exit 1
fi

exec MicroXRCEAgent udp4 -p "${XRCE_PORT}"
