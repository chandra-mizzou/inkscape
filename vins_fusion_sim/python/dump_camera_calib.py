#!/usr/bin/env python3
"""Print Gazebo camera_info as a VINS-Fusion pinhole YAML snippet."""

from __future__ import annotations

import argparse
import sys

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import CameraInfo


class DumpCalib(Node):
    def __init__(self, topic: str) -> None:
        super().__init__("dump_camera_calib")
        self._done = False
        self.create_subscription(CameraInfo, topic, self._cb, 10)
        self.get_logger().info(f"Waiting for CameraInfo on {topic} ...")

    def _cb(self, msg: CameraInfo) -> None:
        if self._done:
            return
        self._done = True
        k = msg.k
        d = list(msg.d) + [0.0] * 4
        yaml = f"""%YAML:1.0
---
model_type: PINHOLE
camera_name: gazebo_mono_cam
image_width: {msg.width}
image_height: {msg.height}
distortion_parameters:
   k1: {d[0]}
   k2: {d[1]}
   p1: {d[2]}
   p2: {d[3]}
projection_parameters:
   fx: {k[0]}
   fy: {k[4]}
   cx: {k[2]}
   cy: {k[5]}
"""
        print(yaml)
        self.get_logger().info("Calibration dumped to stdout. Paste into cam0_pinhole.yaml")
        raise SystemExit(0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--topic", default="/cam0/camera_info")
    args = parser.parse_args()
    rclpy.init()
    node = DumpCalib(args.topic)
    try:
        rclpy.spin(node)
    except SystemExit:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
