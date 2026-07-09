#!/usr/bin/env python3
"""Relay Gazebo-bridged camera/IMU topics onto VINS-Fusion EuRoC-style names.

If ros_gz_bridge already remapped topics via YAML, this node is not required.
It is used as a fallback when the bridge keeps the long Gazebo topic paths.
"""

from __future__ import annotations

import argparse

import rclpy
from rclpy.node import Node
from rclpy.qos import (
    QoSDurabilityPolicy,
    QoSHistoryPolicy,
    QoSProfile,
    QoSReliabilityPolicy,
)
from sensor_msgs.msg import CameraInfo, Image, Imu


def sensor_qos() -> QoSProfile:
    # Gazebo / PX4 bridges typically publish BEST_EFFORT sensor data.
    return QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=10,
        durability=QoSDurabilityPolicy.VOLATILE,
    )


class TopicRemapper(Node):
    def __init__(
        self,
        image_in: str,
        imu_in: str,
        camera_info_in: str,
        image_out: str,
        imu_out: str,
        camera_info_out: str,
    ) -> None:
        super().__init__("vins_topic_remapper")
        qos = sensor_qos()

        self._img_pub = self.create_publisher(Image, image_out, qos)
        self._imu_pub = self.create_publisher(Imu, imu_out, qos)
        self._info_pub = self.create_publisher(CameraInfo, camera_info_out, qos)

        self.create_subscription(Image, image_in, self._on_image, qos)
        self.create_subscription(Imu, imu_in, self._on_imu, qos)
        self.create_subscription(CameraInfo, camera_info_in, self._on_info, qos)

        self.get_logger().info(
            f"Remapping:\n"
            f"  {image_in} -> {image_out}\n"
            f"  {imu_in} -> {imu_out}\n"
            f"  {camera_info_in} -> {camera_info_out}"
        )

    def _on_image(self, msg: Image) -> None:
        self._img_pub.publish(msg)

    def _on_imu(self, msg: Imu) -> None:
        self._imu_pub.publish(msg)

    def _on_info(self, msg: CameraInfo) -> None:
        self._info_pub.publish(msg)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image-in", required=True)
    parser.add_argument("--imu-in", required=True)
    parser.add_argument("--camera-info-in", required=True)
    parser.add_argument("--image-out", default="/cam0/image_raw")
    parser.add_argument("--imu-out", default="/imu0")
    parser.add_argument("--camera-info-out", default="/cam0/camera_info")
    args = parser.parse_args()

    rclpy.init()
    node = TopicRemapper(
        args.image_in,
        args.imu_in,
        args.camera_info_in,
        args.image_out,
        args.imu_out,
        args.camera_info_out,
    )
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
