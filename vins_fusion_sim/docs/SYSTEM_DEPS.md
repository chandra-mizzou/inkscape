# System packages reference (not installable via pip)

Use `scripts/setup_all.sh` to install these. Listed here for documentation / air-gapped setups.

## Ubuntu 22.04 apt

```text
git wget curl build-essential cmake ninja-build pkg-config
python3-pip python3-venv python3-numpy python3-scipy python3-colcon-common-extensions
tmux gnome-terminal
libeigen3-dev libgoogle-glog-dev libsuitesparse-dev libopencv-dev
libboost-all-dev libyaml-cpp-dev geographiclib-tools
```

## ROS 2 Humble

```text
ros-humble-desktop
ros-humble-cv-bridge ros-humble-image-transport
ros-humble-tf2-ros ros-humble-tf2-geometry-msgs
ros-humble-nav-msgs ros-humble-sensor-msgs ros-humble-geometry-msgs
ros-humble-rviz2 ros-humble-rqt-image-view
ros-humble-ros-gz ros-humble-ros-gz-bridge ros-humble-ros-gz-image ros-humble-ros-gz-sim
```

## Gazebo

```text
gz-harmonic
```

## Built from source by setup_all.sh

- PX4-Autopilot (SITL + Gazebo models)
- Micro-XRCE-DDS-Agent
- Ceres Solver 2.1.0
- VINS-Fusion-ROS2 (colcon)
- px4_msgs (colcon)
- QGroundControl AppImage
