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
mkdir -p $USER_HOME/uav_ws  # Create UAV workspace directory if it doesn't exist
mkdir -p $USER_HOME/uav_ws/log  # Create logs directory for the UAV
docker run --rm -it -d --name ros2_uav_px4_cont robotsix/ros2_uav_px4:main  # Start the Docker container
docker cp ros2_uav_px4_cont:/ros_ws/install/ros2_uav_parameters/share/ros2_uav_parameters/config $USER_HOME/uav_ws

# ------------------------------------------------------------------------------
# Create a systemd service file for managing the ROS2 offboard Docker container
# ------------------------------------------------------------------------------
echo "[Unit]
Description=Offboard ROS2 Docker
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker run --rm -it -d --name ros2_uav_offboard --network host -v $USER_HOME/uav_ws/config:/ros_ws/install/ros2_uav_parameters/install/share/ros2_uav_parameters/config -v $USER_HOME/uav_ws/log:/ros_ws/log robotsix/ros2_uav_px4:main
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
# Create ~/.bashrc_offboard
# ------------------------------------------------------------------------------
echo "UAV_NAME=$UAV_NAME" > $USER_HOME/.bashrc_offboard

# Define the shutdown_tmux_window function
cat << 'EOF' >> $USER_HOME/.bashrc_offboard

shutdown_tmux_window() {
    local session="$1"
    local window="$2"
    local docker_container="$3"
    local timeout=30  # Total timeout in seconds
    local interval=1  # Interval between checks in seconds

    if [ -z "$session" ] || [ -z "$window" ] || [ -z "$docker_container" ]; then
        echo "Usage: shutdown_tmux_window <session> <window> <docker_container>"
        return 1
    fi

    echo "Attempting to gracefully terminate processes in tmux window '$window' of session '$session'..."

    # Send Ctrl-C to the specified tmux window
    docker exec "$docker_container" tmux send-keys -t "${session}:${window}" C-c

    # Initialize elapsed time
    local elapsed=0

    while [ "$elapsed" -lt "$timeout" ]; do
        # Get list of current commands in all panes
        current_commands=$(docker exec "$docker_container" tmux list-panes -t "${session}:${window}" -F '#{pane_current_command}')

        # Flag to determine if any active processes are running
        active_processes=false

        while read -r cmd; do
            if [[ "$cmd" != "bash" && "$cmd" != "zsh" && "$cmd" != "sh" ]]; then
                active_processes=true
                echo "Active process detected in pane: $cmd"
            fi
        done <<< "$current_commands"

        if [ "$active_processes" = false ]; then
            echo "No active processes detected in any panes. Killing tmux window '$window'..."
            docker exec "$docker_container" tmux kill-window -t "${session}:${window}"
            echo "tmux window '$window' has been killed successfully."
            return 0
        else
            sleep "$interval"
            elapsed=$((elapsed + interval))
        fi
    done

    echo "Timeout reached. Some processes are still running. tmux window '$window' was not killed."
    return 1
}
EOF

for LAUNCH_FILE in $LAUCH_LIST; do
    LAUNCH_FILE_WE=$(echo $LAUNCH_FILE | cut -d'.' -f1)  # Extract the file name without extension
    # Alias to gracefully stop the node
    echo "alias stop_$LAUNCH_FILE_WE='shutdown_tmux_window uav_session $LAUNCH_FILE_WE ros2_uav_offboard'" >> $USER_HOME/.bashrc_offboard

    # Alias to launch the node
    echo "alias launch_$LAUNCH_FILE_WE='if docker exec ros2_uav_offboard tmux list-windows -t uav_session | grep -q $LAUNCH_FILE_WE; then stop_$LAUNCH_FILE_WE; fi; docker exec ros2_uav_offboard bash -c \"source /ros_ws/install/setup.sh && tmux new-window -t uav_session -n $LAUNCH_FILE_WE\" && docker exec ros2_uav_offboard tmux send-keys -t uav_session:$LAUNCH_FILE_WE \"ros2 launch ros2_uav_px4 $LAUNCH_FILE uav_namespace:=\$UAV_NAME\" Enter'" >> $USER_HOME/.bashrc_offboard
done
# Source ~/.bashrc_offboard in ~/.bashrc if it's not already sourced
if ! grep -q ".bashrc_offboard" $USER_HOME/.bashrc; then
    echo "source $USER_HOME/.bashrc_offboard" >> $USER_HOME/.bashrc
fi

# ------------------------------------------------------------------------------
# Download and compile microDDS agent to enable communication with PX4
# ------------------------------------------------------------------------------
docker pull robotsix/micro_dds_agent:main

# ------------------------------------------------------------------------------
# Start automatically the microDDS agent as a systemd service
# ------------------------------------------------------------------------------
echo "[Unit]
Description=Micro XRCE-DDS Agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/docker run --rm -it -d --name microxrceagent --network host robotsix/micro_dds_agent:main
Restart=always

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/microxrceagent.service

systemctl daemon-reload
systemctl enable microxrceagent.service
systemctl start microxrceagent.service
