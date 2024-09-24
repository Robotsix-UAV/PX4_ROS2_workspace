#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Run Simulation Script
#
# This script automates the stop of the ROS2 2 nodes for simulation with PX4 Autopilot using Docker.
#
# Usage:
#   ./stop_simulation_nodes.sh [options]
#
# Options:
#   -h      Show help message and exit
#   -f      Specify the configuration file for the simulation.
#
# Example:
#   ./stop_simulation_nodes.sh -f config.yaml
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
# Function to gracefully terminate processes in a tmux window
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Stop the simulation nodes
# ------------------------------------------------------------------------------
# Count the number of UAVs in the configuration file
sleep 1
UAV_COUNT=$(( $(yq '.models | length' "$config_file") - 1 ))
for i in $(seq 0 $UAV_COUNT); do
    UAV_NAME=uav$i
    shutdown_tmux_window uav_session $UAV_NAME ros2_uav_px4
done
docker stop ros2_uav_px4
