import rclpy
from rclpy.node import Node
from ros2_uav_interfaces.msg import Coordinate
from px4_msgs.msg import VehicleOdometry
import matplotlib
from matplotlib import pyplot as plt
import math
import threading
from copy import deepcopy

matplotlib.use("TkAgg")  # Ensure Matplotlib uses TkAgg backend, suitable for threading

px4QosProfile = rclpy.qos.qos_profile_sensor_data
px4QosProfile.reliability = rclpy.qos.QoSReliabilityPolicy.BEST_EFFORT

lock = threading.Lock()


class UAVTrajectoryPlotter(Node):
    def __init__(self):
        super().__init__("uav_trajectory_plotter")
        self.coordinates_subscriber = self.create_subscription(
            Coordinate, "/uav0/debug/coordinates", self.coordinates_callback, 20
        )
        self.odometry_subscriber = self.create_subscription(
            VehicleOdometry,
            "/uav0/fmu/out/vehicle_odometry",
            self.odometry_callback,
            px4QosProfile,
        )
        self.fig, self.ax = plt.subplots(
            7, 1, figsize=(10, 15)
        )  # For x, y, z, vx, vy, vz, heading
        self.desired_trajectory = {
            "time_x": [],
            "time_vx": [],
            "time_y": [],
            "time_vy": [],
            "time_z": [],
            "time_vz": [],
            "time_heading": [],
            "x": [],
            "y": [],
            "z": [],
            "vx": [],
            "vy": [],
            "vz": [],
            "heading": [],
        }
        self.actual_trajectory = {
            "time_x": [],
            "time_vx": [],
            "time_y": [],
            "time_vy": [],
            "time_z": [],
            "time_vz": [],
            "time_heading": [],
            "x": [],
            "y": [],
            "z": [],
            "vx": [],
            "vy": [],
            "vz": [],
            "heading": [],
        }
        self.time_init = self.get_clock().now().nanoseconds / 1e9
        self.final_time = 0

    def coordinates_callback(self, msg):
        with lock:
            # Add new trajectory points
            if msg.name == "x":
                self.actual_trajectory["x"] = []
                self.actual_trajectory["vx"] = []
                self.actual_trajectory["time_x"] = []
                self.actual_trajectory["time_vx"] = []
                self.desired_trajectory["time_x"] = msg.timestamps
                self.desired_trajectory["time_vx"] = msg.timestamps
                self.desired_trajectory["x"] = msg.derivatives[0].data
                self.desired_trajectory["vx"] = msg.derivatives[1].data
            elif msg.name == "y":
                self.actual_trajectory["y"] = []
                self.actual_trajectory["vy"] = []
                self.actual_trajectory["time_y"] = []
                self.actual_trajectory["time_vy"] = []
                self.desired_trajectory["time_y"] = msg.timestamps
                self.desired_trajectory["time_vy"] = msg.timestamps
                self.desired_trajectory["y"] = msg.derivatives[0].data
                self.desired_trajectory["vy"] = msg.derivatives[1].data
            elif msg.name == "z":
                self.actual_trajectory["z"] = []
                self.actual_trajectory["vz"] = []
                self.actual_trajectory["time_z"] = []
                self.actual_trajectory["time_vz"] = []
                self.desired_trajectory["time_z"] = msg.timestamps
                self.desired_trajectory["time_vz"] = msg.timestamps
                self.desired_trajectory["z"] = msg.derivatives[0].data
                self.desired_trajectory["vz"] = msg.derivatives[1].data
            elif msg.name == "heading":
                self.actual_trajectory["heading"] = []
                self.actual_trajectory["time_heading"] = []
                self.desired_trajectory["time_heading"] = msg.timestamps
                self.desired_trajectory["heading"] = msg.derivatives[0].data

            self.time_init = self.get_clock().now().nanoseconds / 1e9
            self.final_time = msg.timestamps[-1]

    def odometry_callback(self, msg):
        with lock:
            # Orientation (quaternion to heading)
            heading = self.quaternion_to_heading(
                [msg.q[0], msg.q[1], -msg.q[2], -msg.q[3]]
            )

            # Update actual trajectory data
            current_time = self.get_clock().now().nanoseconds / 1e9 - self.time_init

            if current_time > self.final_time:
                return
            self.actual_trajectory["x"].append(msg.position[0])
            self.actual_trajectory["y"].append(-msg.position[1])
            self.actual_trajectory["z"].append(-msg.position[2])
            self.actual_trajectory["vx"].append(msg.velocity[0])
            self.actual_trajectory["vy"].append(-msg.velocity[1])
            self.actual_trajectory["vz"].append(-msg.velocity[2])
            self.actual_trajectory["heading"].append(heading)

            self.actual_trajectory["time_x"].append(current_time)
            self.actual_trajectory["time_vx"].append(current_time)
            self.actual_trajectory["time_y"].append(current_time)
            self.actual_trajectory["time_vy"].append(current_time)
            self.actual_trajectory["time_z"].append(current_time)
            self.actual_trajectory["time_vz"].append(current_time)
            self.actual_trajectory["time_heading"].append(current_time)

    def quaternion_to_heading(self, quaternion):
        # Convert quaternion to heading
        siny_cosp = 2 * (quaternion[3] * quaternion[2] + quaternion[0] * quaternion[1])
        cosy_cosp = 1 - 2 * (quaternion[1] ** 2 + quaternion[2] ** 2)
        return math.atan2(siny_cosp, cosy_cosp)


def plot_trajectory(node):
    # Function to update the plot with new data
    while rclpy.ok():
        plt.clf()
        labels = [
            "X Position",
            "Y Position",
            "Z Position",
            "X Velocity",
            "Y Velocity",
            "Z Velocity",
            "Heading",
        ]
        with lock:
            desired_trajectory = deepcopy(node.desired_trajectory)
            actual_trajectory = deepcopy(node.actual_trajectory)

        for i, key in enumerate(["x", "y", "z", "vx", "vy", "vz", "heading"]):
            ax = plt.subplot(7, 1, i + 1)
            # Example data fetching; you would use actual data from node attributes
            ax.plot(
                desired_trajectory["time_" + key],
                desired_trajectory[key],
                label="Desired",
            )
            ax.plot(
                actual_trajectory["time_" + key],
                actual_trajectory[key],
                label="Actual",
            )
            ax.set_title(labels[i])
            ax.legend()
        plt.pause(0.01)  # Adjust the pause to manage update frequency


def main(args=None):
    rclpy.init(args=args)
    node = UAVTrajectoryPlotter()

    # Start the ROS node in a separate thread
    ros_thread = threading.Thread(target=lambda: rclpy.spin(node), daemon=True)
    ros_thread.start()

    # Run the plot updates in the main thread
    try:
        plot_trajectory(node)
    except KeyboardInterrupt:
        pass
    finally:
        ros_thread.join()


if __name__ == "__main__":
    main()
