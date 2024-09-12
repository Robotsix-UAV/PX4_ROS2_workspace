#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Run Simulation Script
#
# This script automates the launch of the ROS2 2 nodes for simulation with PX4 Autopilot using Docker.
#
# Usage:
#   ./launch_simulation.sh [options]
#
# Options:
#   -h      Show help message and exit
#   -f      Specify the configuration file for the simulation.
#
# Example:
#   ./launch_simulation.sh -f config.yaml
# ==============================================================================

# ------------------------------------------------------------------------------
# Function to display the help message
# ------------------------------------------------------------------------------
show_help() {
    echo -e "Usage: $0 [-h] [-b branch] [-t tag] [-f configuration_file]"
    echo -e "  -h   Display this help message."
    echo -e "  -f   Specify the configuration file for the simulation."
    echo -e "If no tag or branch is specified, the script will use the current state of the repository if found."
}

# ------------------------------------------------------------------------------
# Define ANSI color codes for output formatting
# ------------------------------------------------------------------------------
RED='\033[0;31m'
NC='\033[0m' # No Color

auto_clone=false

# ------------------------------------------------------------------------------
# Ensure required commands are available
# ------------------------------------------------------------------------------
command -v docker >/dev/null 2>&1 || {
    echo -e "${RED}docker is not installed. Aborting.${NC}"
    exit 1
}

# ------------------------------------------------------------------------------
# Parse command-line options
# ------------------------------------------------------------------------------
while getopts "hb:t:f:a" opt; do
    case ${opt} in
    h)
        show_help
        exit 0
        ;;
    f)
        config_file=${OPTARG}
        ;;
    \?)
        echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
        exit 1
        ;;
    esac
done

# ------------------------------------------------------------------------------
# Check if configuration file is provided
# ------------------------------------------------------------------------------
if [ -z "${config_file}" ]; then
    echo -e "${RED}Configuration file not specified. Use -f option to provide the file.${NC}"
    show_help
    exit 1
fi

# ------------------------------------------------------------------------------
# Docker command to run simulation nodes
# ------------------------------------------------------------------------------
DOCKER_REPO=robotsix/ros2_uav_px4:main
docker pull $DOCKER_REPO
if [ "$(docker ps -q -f name=ros2_uav_px4)" ]; then
    docker stop ros2_uav_px4
fi
docker run -it -d --rm --name ros2_uav_px4 $DOCKER_REPO

# ------------------------------------------------------------------------------
# Execute the simulation nodes
# ------------------------------------------------------------------------------
# Count the number of UAVs in the configuration file
sleep 1
UAV_COUNT=$(( $(yq '.models | length' "$config_file") - 1 ))
for i in $(seq 0 $UAV_COUNT); do
    UAV_NAME=uav$i
    docker exec ros2_uav_px4 bash -c "source /ros_ws/install/setup.sh && tmux new-window -t uav_session -n $UAV_NAME"
    docker exec ros2_uav_px4 tmux send-keys -t uav_session:$UAV_NAME "ros2 launch ros2_uav_px4 offboard.launch.py uav_namespace:=/$UAV_NAME" Enter
done
