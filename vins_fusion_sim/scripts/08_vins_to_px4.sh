#!/usr/bin/env bash
# T8 — Bridge VINS odometry into PX4 visual odometry (EKF2 fusion)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

echo "[T8] VINS -> PX4 visual odometry bridge"
echo "     Converts ENU odometry to NED VehicleOdometry for PX4 EKF2"
sleep 22

exec python3 "${VINS_SIM_DIR}/python/vins_to_px4_vision.py" \
  --odom-in /odometry \
  --fallback-odom /vins_estimator/odometry \
  --px4-out /fmu/in/vehicle_visual_odometry
