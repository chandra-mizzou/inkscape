#!/usr/bin/env bash
# Stop all simulation processes started by this package.
set -euo pipefail

echo "Stopping VINS-Fusion VIO simulation processes..."

# tmux session
if command -v tmux >/dev/null 2>&1; then
  tmux has-session -t "=vins-fusion-vio" 2>/dev/null && tmux kill-session -t "vins-fusion-vio" && echo "  killed tmux session vins-fusion-vio"
fi

# Individual processes (best-effort)
pkill -f "px4_sitl|bin/px4" 2>/dev/null || true
pkill -f "MicroXRCEAgent" 2>/dev/null || true
pkill -f "ros_gz_bridge" 2>/dev/null || true
pkill -f "topic_remapper.py" 2>/dev/null || true
pkill -f "vins_to_px4_vision.py" 2>/dev/null || true
pkill -f "vins_node|loop_fusion" 2>/dev/null || true
pkill -f "QGroundControl" 2>/dev/null || true
pkill -f "gz sim|gazebo" 2>/dev/null || true
pkill -f "rviz2" 2>/dev/null || true

sleep 1
echo "Done. Leftover ROS nodes (if any):"
ros2 node list 2>/dev/null || echo "  (ros2 not available / no daemon)"
