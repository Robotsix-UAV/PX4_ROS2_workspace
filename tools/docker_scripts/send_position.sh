#!/bin/bash

# ==============================================================================
# UAV Pose Heading Publisher Script
#
# This script sends a PoseHeading command to the UAV via ROS2. It publishes a
# single message to the /<uav_namespace>/command/pose_heading topic using Docker
# to execute the command inside the ros2_uav_px4 container.
#
# Usage:
#   ./publish_pose_heading.sh <uav_namespace> <x> <y> <z> <heading>
#
# Example:
#   ./publish_pose_heading.sh uav0 10.0 5.0 3.0 90.0
# ==============================================================================

# Ensure the script receives exactly 5 arguments
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <uav_namespace> <x> <y> <z> <heading>"
    exit 1
fi

# Assign positional parameters to variables for readability
UAV_NAMESPACE=$1
X=$2
Y=$3
Z=$4
HEADING=$5

# ------------------------------------------------------------------------------
# Publish the PoseHeading message to the /<uav_namespace>/command/pose_heading topic
# ------------------------------------------------------------------------------
docker exec -it ros2_uav_px4 /bin/bash -c "source /ros_ws/install/setup.sh && ros2 topic pub -1 /$UAV_NAMESPACE/command/pose_heading ros2_uav_interfaces/msg/PoseHeading '{
  header: {
    stamp: {sec: 123456789, nanosec: 0},
    frame_id: \"$UAV_NAMESPACE/origin\"
  },
  position: {
    x: $X,
    y: $Y,
    z: $Z
  },
  velocity: {
    x: 0.0,
    y: 0.0,
    z: 0.0
  },
  heading: $HEADING
}'"
