#!/usr/bin/env python3
"""Convert VINS-Fusion odometry (ENU) to PX4 VehicleOdometry (NED / FRD).

Publishes on /fmu/in/vehicle_visual_odometry so PX4 EKF2 can fuse vision.
Requires px4_msgs in the ROS 2 workspace and MicroXRCEAgent running.

Coordinate transform (ROS ENU -> PX4 NED):
  x_ned =  y_enu
  y_ned =  x_enu
  z_ned = -z_enu
Quaternion: swap / negate components accordingly (see body of converter).
"""

from __future__ import annotations

import argparse
import math
from typing import Optional

import rclpy
from geometry_msgs.msg import PoseWithCovarianceStamped
from nav_msgs.msg import Odometry
from rclpy.node import Node
from rclpy.qos import (
    QoSDurabilityPolicy,
    QoSHistoryPolicy,
    QoSProfile,
    QoSReliabilityPolicy,
)


def try_import_px4():
    try:
        from px4_msgs.msg import VehicleOdometry  # type: ignore

        return VehicleOdometry
    except ImportError:
        return None


def enu_quat_to_ned(qx: float, qy: float, qz: float, qw: float):
    """Convert orientation from ENU/FLU to NED/FRD."""
    # Equivalent to a 180° rotation about x composed with 90° about z in frame change.
    # Common PX4 ROS bridge mapping:
    #   q_ned = (qw, qy, qx, -qz) after axis remap of the rotation.
    return qy, qx, -qz, qw


def enu_pos_to_ned(x: float, y: float, z: float):
    return y, x, -z


def enu_vel_to_ned(vx: float, vy: float, vz: float):
    return vy, vx, -vz


class VinsToPx4(Node):
    def __init__(self, odom_in: str, fallback_odom: str, px4_out: str) -> None:
        super().__init__("vins_to_px4_vision")
        self._VehicleOdometry = try_import_px4()
        if self._VehicleOdometry is None:
            self.get_logger().error(
                "px4_msgs not found. Build PX4/px4_msgs into your ROS 2 workspace.\n"
                "  cd $ROS2_WS/src && git clone https://github.com/PX4/px4_msgs.git\n"
                "  cd $ROS2_WS && colcon build --packages-select px4_msgs"
            )

        qos_be = QoSProfile(
            reliability=QoSReliabilityPolicy.BEST_EFFORT,
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
            durability=QoSDurabilityPolicy.VOLATILE,
        )
        qos_rel = QoSProfile(
            reliability=QoSReliabilityPolicy.RELIABLE,
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
            durability=QoSDurabilityPolicy.VOLATILE,
        )

        self._pub = None
        if self._VehicleOdometry is not None:
            # PX4 XRCE subscriptions expect BEST_EFFORT + VOLATILE
            self._pub = self.create_publisher(self._VehicleOdometry, px4_out, qos_be)

        self._count = 0
        self.create_subscription(Odometry, odom_in, self._on_odom, qos_rel)
        self.create_subscription(Odometry, fallback_odom, self._on_odom, qos_rel)
        # Some VINS forks publish PoseWithCovarianceStamped
        self.create_subscription(
            PoseWithCovarianceStamped, "/vins_estimator/pose", self._on_pose, qos_rel
        )

        self.get_logger().info(
            f"Listening for VINS odometry on {odom_in} / {fallback_odom}\n"
            f"Publishing PX4 visual odometry on {px4_out}"
        )
        self.create_timer(5.0, self._heartbeat)

    def _heartbeat(self) -> None:
        self.get_logger().info(f"Forwarded {self._count} vision odometry messages so far")

    def _publish_ned(
        self,
        stamp_sec: int,
        stamp_nsec: int,
        x: float,
        y: float,
        z: float,
        qx: float,
        qy: float,
        qz: float,
        qw: float,
        vx: float = 0.0,
        vy: float = 0.0,
        vz: float = 0.0,
    ) -> None:
        if self._pub is None or self._VehicleOdometry is None:
            return

        px, py, pz = enu_pos_to_ned(x, y, z)
        pqx, pqy, pqz, pqw = enu_quat_to_ned(qx, qy, qz, qw)
        # Normalize
        n = math.sqrt(pqx * pqx + pqy * pqy + pqz * pqz + pqw * pqw) or 1.0
        pqx, pqy, pqz, pqw = pqx / n, pqy / n, pqz / n, pqw / n
        nvx, nvy, nvz = enu_vel_to_ned(vx, vy, vz)

        msg = self._VehicleOdometry()
        # PX4 timestamp in microseconds
        msg.timestamp = int(stamp_sec * 1e6 + stamp_nsec * 1e-3)
        msg.timestamp_sample = msg.timestamp

        # Pose frame: NED; velocity frame: NED
        # Enum values from px4_msgs VehicleOdometry
        if hasattr(msg, "POSE_FRAME_NED"):
            msg.pose_frame = msg.POSE_FRAME_NED
        else:
            msg.pose_frame = 1
        if hasattr(msg, "VELOCITY_FRAME_NED"):
            msg.velocity_frame = msg.VELOCITY_FRAME_NED
        else:
            msg.velocity_frame = 1

        msg.position = [float(px), float(py), float(pz)]
        msg.q = [float(pqw), float(pqx), float(pqy), float(pqz)]  # PX4 uses w,x,y,z
        msg.velocity = [float(nvx), float(nvy), float(nvz)]
        msg.angular_velocity = [float("nan")] * 3

        # Position variance (m^2) — conservative defaults
        msg.position_variance = [0.05, 0.05, 0.08]
        msg.orientation_variance = [0.05, 0.05, 0.1]
        msg.velocity_variance = [0.1, 0.1, 0.1]

        self._pub.publish(msg)
        self._count += 1

    def _on_odom(self, msg: Odometry) -> None:
        p = msg.pose.pose.position
        q = msg.pose.pose.orientation
        v = msg.twist.twist.linear
        self._publish_ned(
            msg.header.stamp.sec,
            msg.header.stamp.nanosec,
            p.x,
            p.y,
            p.z,
            q.x,
            q.y,
            q.z,
            q.w,
            v.x,
            v.y,
            v.z,
        )

    def _on_pose(self, msg: PoseWithCovarianceStamped) -> None:
        p = msg.pose.pose.position
        q = msg.pose.pose.orientation
        self._publish_ned(
            msg.header.stamp.sec,
            msg.header.stamp.nanosec,
            p.x,
            p.y,
            p.z,
            q.x,
            q.y,
            q.z,
            q.w,
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--odom-in", default="/odometry")
    parser.add_argument("--fallback-odom", default="/vins_estimator/odometry")
    parser.add_argument("--px4-out", default="/fmu/in/vehicle_visual_odometry")
    args = parser.parse_args()

    rclpy.init()
    node = VinsToPx4(args.odom_in, args.fallback_odom, args.px4_out)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
