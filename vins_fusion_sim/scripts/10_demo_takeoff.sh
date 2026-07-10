#!/usr/bin/env bash
# Optional helper: arm + takeoff via MAVSDK (PX4 SITL default companion port).
# Usage: ./scripts/10_demo_takeoff.sh [altitude_m]
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../config/env.sh"

ALT="${1:-3.0}"
export DEMO_TAKEOFF_ALT="${ALT}"

echo "[demo] Takeoff helper (target altitude ${ALT} m)"
echo "       Prefer QGC: Arm → Takeoff if this fails."

python3 - <<'PY'
import asyncio
import os
import sys

ALT = float(os.environ.get("DEMO_TAKEOFF_ALT", "3.0"))

async def main():
    try:
        from mavsdk import System
    except ImportError:
        print("[demo] mavsdk not installed (pip install mavsdk)")
        sys.exit(2)

    drone = System()
    await drone.connect(system_address="udp://:14540")
    print("[demo] Waiting for PX4 connection on udp://:14540 ...")
    async for state in drone.core.connection_state():
        if state.is_connected:
            print("[demo] Connected.")
            break

    print("[demo] Waiting for vehicle to be armable / have a position estimate...")
    async for health in drone.telemetry.health():
        if health.is_armable or health.is_global_position_ok or health.is_local_position_ok:
            break
        await asyncio.sleep(0.5)

    print(f"[demo] Arming and taking off to {ALT:.1f} m")
    await drone.action.arm()
    await drone.action.set_takeoff_altitude(ALT)
    await drone.action.takeoff()
    print("[demo] Takeoff commanded. Fly a slow figure-8 in QGC so VINS can initialize.")

try:
    asyncio.run(main())
except SystemExit as e:
    raise
except Exception as exc:
    print(f"[demo] Automatic takeoff failed: {exc}")
    sys.exit(1)
PY
status=$?

if [[ "${status}" -ne 0 ]]; then
  echo ""
  echo "[demo] Automatic takeoff unavailable (exit ${status})."
  echo "       In QGroundControl:"
  echo "         1. Wait until the vehicle shows Ready / GPS OK"
  echo "         2. Click Arm (or Safety → Arm)"
  echo "         3. Takeoff to ~${ALT} m"
  echo "         4. Fly a slow figure-8 so VINS can initialize"
fi
