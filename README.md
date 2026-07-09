# VINS-Fusion VIO Simulation Stack

This repository provides a **multi-terminal shell launcher** to run **VINS-Fusion visual-inertial odometry** on a **PX4 Gazebo SITL** simulated camera, with **QGroundControl** and **ROS 2**.

## Start here

All simulation assets live in [`vins_fusion_sim/`](vins_fusion_sim/):

```bash
cd vins_fusion_sim
./scripts/setup_all.sh --yes          # creates ~/vins_ws and builds it (required first)
source scripts/source_env.sh          # sources ROS2 + ~/vins_ws/install/setup.bash
./scripts/run_vins_fusion_sim.sh      # open T1–T9 terminals and start the stack
```

If `source ~/vins_ws/install/setup.bash` fails with “No such file”, the workspace was never built — run `setup_all.sh` first.

- **Full guide** (steps, what to expect, troubleshooting): [`vins_fusion_sim/README.md`](vins_fusion_sim/README.md)
- **Python helpers**: [`vins_fusion_sim/requirements.txt`](vins_fusion_sim/requirements.txt)

## Quick picture

1. Gazebo + PX4 SITL spawn an X500 with a mono camera and IMU  
2. `ros_gz_bridge` publishes `/cam0/image_raw` and `/imu0`  
3. VINS-Fusion estimates pose; optional bridge feeds PX4 EKF2 vision  
4. Fly the vehicle from QGroundControl and watch the path in RViz2  
