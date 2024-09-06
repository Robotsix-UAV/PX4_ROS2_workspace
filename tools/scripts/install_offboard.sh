#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# ROS2 UAV PX4 Setup Script
#
# This script automates the process of setting up the ROS2 environment for UAV control
# using Docker and systemd services. It pulls the required Docker image, sets up configuration
# files, and creates a systemd service to manage the Docker container for ROS2 offboard control.
# The script also generates aliases for launch commands to simplify running ROS2 launch files
# within a tmux session.
#
# Usage:
#   ./install_offboard.sh uav_name
# ==============================================================================

# ------------------------------------------------------------------------------
# Check if the script is being run as root
# ------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# ------------------------------------------------------------------------------
# Get the user's home directory
# ------------------------------------------------------------------------------
USER_HOME=$(eval echo /home/${SUDO_USER})

# ------------------------------------------------------------------------------
# Check usage and set UAV name
# ------------------------------------------------------------------------------
if [ $# -ne 1 ]; then
    echo "Usage: ./install_offboard.sh uav_name"
    exit 1
fi
UAV_NAME=$1

# ------------------------------------------------------------------------------
# Pull the Docker image for ROS2 UAV PX4
# ------------------------------------------------------------------------------
docker pull robotsix/ros2_uav_px4:main

# ------------------------------------------------------------------------------
# Set up configuration files by copying them from the Docker container to the local workspace
# ------------------------------------------------------------------------------
mkdir -p ~/uav_ws  # Create UAV workspace directory if it doesn't exist
docker run --rm -it -d --name ros2_uav_px4_cont robotsix/ros2_uav_px4:main  # Start the Docker container
docker cp ros2_uav_px4_cont:/ros_ws/install/ros2_uav_parameters/share/ros2_uav_parameters/config /uav_ws

# ------------------------------------------------------------------------------
# Create a systemd service file for managing the ROS2 offboard Docker container
# ------------------------------------------------------------------------------
echo "[Unit]
Description=Offboard ROS2 Docker
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker run --rm -it -d --name ros2_uav_offboard --network host -v /uav_ws/config:/ros_ws/install/ros2_uav_parameters/install/share/ros2_uav_parameters/config robotsix/ros2_uav_px4:main
ExecStop=/usr/bin/docker stop ros2_uav_offboard

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/ros2_offboard.service

# ------------------------------------------------------------------------------
# Enable and start the systemd service for the ROS2 offboard Docker container
# ------------------------------------------------------------------------------
systemctl daemon-reload  # Reload systemd to recognize the new service
systemctl enable ros2_offboard.service  # Enable the service to start on boot
systemctl start ros2_offboard.service   # Start the service immediately

# ------------------------------------------------------------------------------
# List available launch files from the ROS2 UAV PX4 Docker container
# ------------------------------------------------------------------------------
sleep 2  # Wait for the Docker container to start
LAUCH_LIST=$(docker exec ros2_uav_offboard ls /ros_ws/install/ros2_uav_px4/share/ros2_uav_px4/launch)
echo "Available launch files:"
echo "$LAUCH_LIST"

# ------------------------------------------------------------------------------
# Create command aliases in ~/.bashrc for each launch file to simplify execution
# ------------------------------------------------------------------------------
echo "UAV_NAME=$UAV_NAME" >> $USER_HOME/.bashrc
for LAUNCH_FILE in $LAUCH_LIST; do
    LAUNCH_FILE_WE=$(echo $LAUNCH_FILE | cut -d'.' -f1)  # Extract the file name without extension
    # Add alias to ~/.bashrc to create a new tmux window for each launch file in the 'uav_session'
    echo "alias launch_$LAUNCH_FILE_WE='if docker exec ros2_uav_offboard tmux list-windows -t uav_session | grep -q $LAUNCH_FILE_WE; then docker exec ros2_uav_offboard tmux kill-window -t uav_session:\$LAUNCH_FILE_WE; fi; docker exec ros2_uav_offboard bash -c \"source /ros_ws/install/setup.sh && tmux new-window -t uav_session -n $LAUNCH_FILE_WE \\\"ros2 launch ros2_uav_px4 $LAUNCH_FILE uav_namespace:=\$UAV_NAME\\\"\"'" >> $USER_HOME/.bashrc
done

# ------------------------------------------------------------------------------
# Download and compile microDDS agent to enable communication with PX4
# ------------------------------------------------------------------------------
git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
cd Micro-XRCE-DDS-Agent
mkdir -p build && cd build
cmake ..
make -s
make install -s >> /dev/null
ldconfig /usr/local/lib/

# ------------------------------------------------------------------------------
# Start automatically the microDDS agent as a systemd service
# ------------------------------------------------------------------------------
echo "[Unit]
Description=Micro XRCE-DDS Agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/MicroXRCEAgent udp4 -p 8888
Restart=always

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/microxrceagent.service

systemctl daemon-reload
systemctl enable microxrceagent.service
systemctl start microxrceagent.service
