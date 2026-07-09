# VINS-Fusion VIO Simulation (PX4 + Gazebo + QGC + ROS 2)

Multi-terminal shell stack that runs **VINS-Fusion visual-inertial odometry** on a **simulated mono camera + IMU** from **PX4 Gazebo SITL**, with **QGroundControl** for flying the vehicle and **ROS 2** for bridging and estimation.

```
QGroundControl ──MAVLink──► PX4 SITL ◄──Gazebo──► camera + IMU
                               │
                          MicroXRCEAgent
                               │
                            ROS 2 DDS
                               │
              ros_gz_bridge ──► /cam0/image_raw , /imu0
                               │
                          VINS-Fusion
                               │
                    /odometry (ENU) ──► vins_to_px4_vision.py
                               │
                    /fmu/in/vehicle_visual_odometry (NED)
                               │
                          PX4 EKF2 (vision fusion)
```

---

## What you get

| Item | Path |
|------|------|
| Multi-terminal launcher | `scripts/run_vins_fusion_sim.sh` |
| Per-process scripts (T1–T9) | `scripts/01_*.sh` … `09_*.sh` |
| One-shot installer | `scripts/setup_all.sh` |
| Python helpers | `python/topic_remapper.py`, `vins_to_px4_vision.py` |
| VINS config for Gazebo mono+IMU | `config/gazebo_mono_imu_config.yaml` |
| Pip packages | `requirements.txt` |
| Stop everything | `scripts/stop_sim.sh` |

---

## System requirements

| Component | Recommended version |
|-----------|---------------------|
| OS | Ubuntu **22.04** (Jammy) |
| ROS 2 | **Humble** |
| Gazebo | **Harmonic** (`gz-harmonic`) |
| PX4 | Autopilot **v1.14+** / `main` with `gz_x500_mono_cam` |
| QGroundControl | Latest AppImage |
| VINS-Fusion | [zinuok/VINS-Fusion-ROS2](https://github.com/zinuok/VINS-Fusion-ROS2) (or Humble fork) |
| DDS bridge | Micro XRCE-DDS Agent |
| Display | Local GUI, or `tmux` over SSH |

> `requirements.txt` covers **Python** helpers only. ROS, Gazebo, PX4, Ceres, and QGC are installed by `setup_all.sh` (or manually as below).

---

## Quick start

### 1. Install everything

```bash
cd vins_fusion_sim
chmod +x scripts/*.sh python/*.py
./scripts/setup_all.sh --yes
```

This will (when missing):

1. Install apt packages (build tools, Eigen, OpenCV, tmux, …)
2. Install ROS 2 Humble + `ros-gz` bridge packages
3. Install Gazebo Harmonic
4. Clone & build **PX4-Autopilot** SITL
5. Build **MicroXRCEAgent**
6. Download **QGroundControl** AppImage
7. Create `~/vins_ws`, clone **px4_msgs** + **VINS-Fusion-ROS2**, install **Ceres**, `colcon build`
8. `pip install -r requirements.txt`

Python-only:

```bash
./scripts/setup_all.sh --python-only
# or
python3 -m pip install -r requirements.txt
```

### 2. Source your environment

> **Important:** `~/vins_ws/install/setup.bash` does **not** exist until step 1 finishes.
> If you see `No such file or directory`, run `./scripts/setup_all.sh --yes` first
> (that creates `~/vins_ws`, clones VINS-Fusion + px4_msgs, and runs `colcon build`).

Preferred (checks paths and prints a clear fix if something is missing):

```bash
source scripts/source_env.sh
```

Or manually:

```bash
source /opt/ros/humble/setup.bash
source ~/vins_ws/install/setup.bash   # only after setup_all.sh / colcon build
export PX4_DIR=$HOME/PX4-Autopilot
export ROS2_WS=$HOME/vins_ws
export QGC_APPIMAGE=$HOME/QGroundControl.AppImage
```

Optional: put those lines in `~/.bashrc`. Paths can be overridden in `config/env.sh`.

### 3. Launch the multi-terminal simulation

```bash
./scripts/run_vins_fusion_sim.sh
```

Useful flags:

```bash
./scripts/run_vins_fusion_sim.sh --dry-run   # print plan only
./scripts/run_vins_fusion_sim.sh --tmux      # force tmux windows
./scripts/run_vins_fusion_sim.sh --no-qgc    # no QGroundControl
./scripts/run_vins_fusion_sim.sh --no-rviz   # no RViz2
./scripts/run_vins_fusion_sim.sh --no-loop   # skip loop_fusion
```

Stop everything:

```bash
./scripts/stop_sim.sh
```

---

## Terminals opened by the launcher

| # | Title | Script | What it does |
|---|--------|--------|----------------|
| T1 | PX4-SITL-Gazebo | `01_px4_sitl.sh` | Starts PX4 SITL and Gazebo with `gz_x500_mono_cam` |
| T2 | QGroundControl | `02_qgroundcontrol.sh` | Operator UI (arm / takeoff / fly) |
| T3 | MicroXRCEAgent | `03_micro_xrce_agent.sh` | PX4 uORB ↔ ROS 2 DDS on UDP `8888` |
| T4 | ros_gz_bridge | `04_ros_gz_bridge.sh` | Gazebo camera + IMU → ROS 2 |
| T5 | topic-remap | `05_topic_remap.sh` | Ensures `/cam0/image_raw` and `/imu0` exist |
| T6 | VINS-Fusion | `06_vins_fusion.sh` | Runs the VIO estimator |
| T7 | loop-fusion | `07_loop_fusion.sh` | Pose-graph loop closure (optional) |
| T8 | vins-to-px4 | `08_vins_to_px4.sh` | ENU odom → PX4 `VehicleOdometry` (NED) |
| T9 | RViz2 | `09_rviz.sh` | Path / tracked features visualization |

Startup is staggered so Gazebo and bridges come up before VINS.

---

## What to expect (step by step)

### After launch

1. **Gazebo** opens a 3D world with an **X500** quadrotor and a **forward mono camera**.
2. **PX4** console prints `READY` / `EKF2` status; GPS lock appears in simulation.
3. **QGroundControl** auto-connects (UDP 14550). You should see one vehicle.
4. **MicroXRCEAgent** logs client sessions when PX4 connects.
5. **ros_gz_bridge** creates bridges; shortly after, these topics exist:
   ```bash
   ros2 topic list | grep -E 'cam0|imu0'
   ros2 topic hz /cam0/image_raw
   ros2 topic hz /imu0
   ```
   Expect ~20–30 Hz images and ~100–250 Hz IMU (model-dependent).
6. **VINS-Fusion** prints initialization messages. Until the drone moves with enough parallax, pose may stay near the origin.
7. **RViz2** shows `/image_track` (feature tracks) once VINS is running, and `/odometry` / `/path` after motion.

### Flying for good VIO

In QGroundControl:

1. Wait until the vehicle is ready (GPS OK in SITL).
2. **Arm** → **Takeoff** to ~2–5 m.
3. Fly a **slow figure-8 or rectangle** with yaw changes — VINS needs translation + rotation to initialize and stay healthy.
4. Avoid pure hover for long periods right after start; give it textured scenery in view (default Gazebo world is OK; richer worlds help).

### Feeding vision into PX4 EKF2 (optional)

1. Load `config/px4_ekf2_vision.params` in QGC (**Parameters → Tools → Load from file**), or set in the PX4 shell:
   ```text
   param set EKF2_EV_CTRL 11
   param set EKF2_EV_DELAY 50
   reboot
   ```
2. Confirm T8 is publishing:
   ```bash
   ros2 topic hz /fmu/in/vehicle_visual_odometry
   ```
3. In PX4 `listener vehicle_visual_odometry` (nsh) you should see updates while VINS tracks.

### Healthy run checklist

| Check | Healthy sign |
|-------|----------------|
| `ros2 topic hz /cam0/image_raw` | steady rate, no timeouts |
| `ros2 topic hz /imu0` | high rate IMU |
| VINS terminal | no constant “waiting for image/imu”; features tracked |
| RViz `/path` | trajectory grows as you fly |
| QGC | vehicle controllable; no failsafe spam |

### When something is wrong

| Symptom | Likely cause | Fix |
|---------|----------------|-----|
| `~/vins_ws/install/setup.bash: No such file or directory` | Workspace never built | Run `./scripts/setup_all.sh --yes`, then `source scripts/source_env.sh` |
| `AMENT_TRACE_SETUP_FILES: unbound variable` | `set -u` + ROS setup.bash | Pull latest scripts (fixed via `vins_source_ros_setup`); or run `set +u` before sourcing ROS |
| No Gazebo window | DISPLAY / GPU / first PX4 build | Run T1 alone; finish `make px4_sitl gz_x500_mono_cam` |
| QGC no vehicle | SITL not up / firewall | Wait for T1; confirm UDP 14550 |
| No `/cam0/image_raw` | Wrong Gazebo topic name | `gz topic -l \| grep image` and set `GZ_IMAGE_TOPIC` / `GZ_MODEL_NAME` in `config/env.sh` |
| VINS “waiting for image” | Bridge/QoS | Ensure T4/T5 running; BEST_EFFORT remapper is used |
| VINS diverges | Bad extrinsics / texture / motion | Set `estimate_extrinsic: 2`, fly slower, improve world texture |
| No `px4_msgs` | Workspace not built | `cd ~/vins_ws && colcon build --packages-select px4_msgs && source install/setup.bash` |
| Agent not found | XRCE not installed | Re-run `setup_all.sh` or install Micro-XRCE-DDS-Agent |

---

## Manual terminal-by-terminal (without the launcher)

If you prefer to start each piece yourself:

```bash
# T1
cd $PX4_DIR && make px4_sitl gz_x500_mono_cam

# T2
$HOME/QGroundControl.AppImage

# T3
MicroXRCEAgent udp4 -p 8888

# T4 (example — adjust model name from `gz topic -l`)
ros2 run ros_gz_bridge parameter_bridge \
  /world/default/model/x500_mono_cam_0/link/camera_link/sensor/imager/image@sensor_msgs/msg/Image@gz.msgs.Image \
  /world/default/model/x500_mono_cam_0/link/base_link/sensor/imu_sensor/imu@sensor_msgs/msg/Imu@gz.msgs.IMU

# T5 (if topics were not remapped)
python3 python/topic_remapper.py \
  --image-in /world/default/model/x500_mono_cam_0/link/camera_link/sensor/imager/image \
  --imu-in /world/default/model/x500_mono_cam_0/link/base_link/sensor/imu_sensor/imu \
  --camera-info-in /world/default/model/x500_mono_cam_0/link/camera_link/sensor/imager/camera_info

# T6
ros2 run vins vins_node $(pwd)/config/gazebo_mono_imu_config.yaml

# T7
ros2 run loop_fusion loop_fusion_node $(pwd)/config/gazebo_mono_imu_config.yaml

# T8
python3 python/vins_to_px4_vision.py

# T9
rviz2 -d config/vins_sim.rviz
```

---

## Configuration tips

### Environment (`config/env.sh`)

| Variable | Default | Meaning |
|----------|---------|---------|
| `PX4_DIR` | `~/PX4-Autopilot` | PX4 source tree |
| `ROS2_WS` | `~/vins_ws` | colcon workspace with vins + px4_msgs |
| `PX4_SIM_MODEL` | `gz_x500_mono_cam` | Gazebo airframe with camera |
| `GZ_MODEL_NAME` | `x500_mono_cam_0` | Instance name inside topic paths |
| `VINS_CONFIG` | `config/gazebo_mono_imu_config.yaml` | Estimator YAML |
| `TERM_BACKEND` | `auto` | `gnome-terminal` / `tmux` / `xterm` / `sequential` |

### Camera calibration

Default intrinsics are approximate. After the bridge is up:

```bash
python3 python/dump_camera_calib.py --topic /cam0/camera_info
```

Paste the printed YAML into `config/cam0_pinhole.yaml`, then restart VINS.

### Extrinsics

`body_T_cam0` in `gazebo_mono_imu_config.yaml` is an initial guess for the forward camera. For first bring-up, `estimate_extrinsic: 1` or `2` is recommended.

---

## `requirements.txt` vs system packages

**Pip (`requirements.txt`)** — used by helper nodes:

- `numpy`, `scipy`, `PyYAML`, `opencv-python-headless`, `transforms3d`, `pymavlink`, `mavsdk`, `matplotlib`, …

**Not in pip** (installed by `setup_all.sh` / apt):

- ROS 2 Humble desktop + `ros-gz-bridge`
- Gazebo Harmonic
- PX4 Autopilot + SITL
- Micro XRCE-DDS Agent
- QGroundControl
- Ceres Solver, Eigen, OpenCV (system), VINS-Fusion source

---

## Repository layout

```text
vins_fusion_sim/
├── README.md
├── requirements.txt
├── config/
│   ├── env.sh
│   ├── gazebo_mono_imu_config.yaml
│   ├── cam0_pinhole.yaml
│   ├── ros_gz_bridge.yaml
│   ├── px4_ekf2_vision.params
│   └── vins_sim.rviz
├── python/
│   ├── topic_remapper.py
│   ├── vins_to_px4_vision.py
│   └── dump_camera_calib.py
└── scripts/
    ├── setup_all.sh
    ├── run_vins_fusion_sim.sh    ← main multi-terminal entrypoint
    ├── stop_sim.sh
    ├── 01_px4_sitl.sh
    ├── 02_qgroundcontrol.sh
    ├── 03_micro_xrce_agent.sh
    ├── 04_ros_gz_bridge.sh
    ├── 05_topic_remap.sh
    ├── 06_vins_fusion.sh
    ├── 07_loop_fusion.sh
    ├── 08_vins_to_px4.sh
    └── 09_rviz.sh
```

---

## License / credits

- [PX4 Autopilot](https://px4.io/)
- [VINS-Fusion](https://github.com/HKUST-Aerial-Robotics/VINS-Fusion) / ROS 2 ports
- [Gazebo](https://gazebosim.org/) / [ros_gz](https://github.com/gazebosim/ros_gz)
- [QGroundControl](https://qgroundcontrol.com/)
- [eProsima Micro XRCE-DDS](https://github.com/eProsima/Micro-XRCE-DDS-Agent)
