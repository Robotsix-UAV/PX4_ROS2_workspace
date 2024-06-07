#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Test Script for launch_simulation.sh
#
# This script is designed to test the functionality of the launch_simulation.sh
# script by running it with sample configuration files and ensuring it
# executes correctly.
#
# Usage:
#   ./test_launch_simulation.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# Print a message indicating the start of the test
# ------------------------------------------------------------------------------
echo "Running launch_simulation.sh test"
CONTAINER_NAME="px4_sitl"

# ------------------------------------------------------------------------------
# Function to check the result of the last executed command and exit if it failed
# ------------------------------------------------------------------------------
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2 failed"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Function to check if a file exists and exit if it doesn't
# ------------------------------------------------------------------------------
check_file_exists() {
    if [ ! -f "$1" ]; then
        echo "Error: $2 not found"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Function to check if a model is spawned in Gazebo and exit if it isn't
# ------------------------------------------------------------------------------
check_model_spawned() {
    local model_name="$1"
    local container_name="$2"
    local retries=10
    local wait_time=2

    echo "Checking for model $model_name in Gazebo..."

    gazebo_running=false
    # Check that gazebo is running
    for ((i = 1; i <= retries; i++)); do
        docker exec "$container_name" pgrep -x ruby >/dev/null
        if [ $? -eq 0 ]; then
            echo "Gazebo is running."
            gazebo_running=true
            break
        fi
        echo "Waiting for Gazebo to start... ($i/$retries)"
        sleep $wait_time
    done

    if [ "$gazebo_running" = false ]; then
        echo "Error: Gazebo client not running"
        exit 1
    fi

    # Check that the models are spawned in Gazebo
    j=0
    for ((i = 1; i <= retries; i++)); do
        docker exec "$container_name" gz model --list | grep ${model_name}_${j}
        if [ $? -eq 0 ]; then
            echo "Model ${model_name}_${j} is spawned in Gazebo."
            j=$((j + 1))
        fi
        if [ $j -eq 2 ]; then
            break
        fi
        echo "Waiting for model ${model_name}_${j} to spawn in Gazebo... ($i/$retries)"
        sleep $wait_time
    done

    if [ $j -ne 2 ]; then
        echo "Error: Model ${model_name}_${j} not spawned in Gazebo"
        exit 1
    fi

    echo "All models spawned in Gazebo."
}

# ------------------------------------------------------------------------------
# Function to check if a PX4 process is running inside the Docker container
# ------------------------------------------------------------------------------
check_px4_running() {
    local container_name="$1"
    docker exec "$container_name" pgrep -x px4 >/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: PX4 process not running"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Function to check if a MicroXRCEAgent process is running inside the Docker container
# ------------------------------------------------------------------------------
check_agent_running() {
    local container_name="$1"
    docker exec "$container_name" pgrep -x MicroXRCEAgent >/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: MicroXRCEAgent process not running"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Function to clean up the test environment
# ------------------------------------------------------------------------------
cleanup() {
    echo "Cleaning up"
    docker stop px4_sitl >/dev/null 2>&1 || true
    DOCKER_REPO=robotsix/px4_fw_upload:main
    docker run --rm -w "$SCRIPT_DIR" -v $SCRIPT_DIR/..:$SCRIPT_DIR/..:rw $DOCKER_REPO bash -c "rm -rf ../PX4-Autopilot"
}

# ------------------------------------------------------------------------------
# Trap cleanup function on exit
# ------------------------------------------------------------------------------
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Get the directory of the script
# ------------------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname "$0"))

# ------------------------------------------------------------------------------
# Define the path to the sample configuration files
# ------------------------------------------------------------------------------
CONFIG_DIR="$SCRIPT_DIR"
CONFIG_FILE_1="$CONFIG_DIR/simulation_config.yaml"
CONFIG_FILE_2="$CONFIG_DIR/simulation_config_custom.yaml"

# ------------------------------------------------------------------------------
# Ensure the configuration files exist
# ------------------------------------------------------------------------------
check_file_exists "$CONFIG_FILE_1" "simulation_config.yaml"
check_file_exists "$CONFIG_FILE_2" "simulation_config_custom.yaml"

# ------------------------------------------------------------------------------
# Run the launch_simulation.sh script with the first configuration file
# ------------------------------------------------------------------------------
$SCRIPT_DIR/../tools/docker_scripts/launch_simulation.sh -f $CONFIG_FILE_1 -a -b main
check_result $? "launch_simulation.sh with simulation_config.yaml"

# ------------------------------------------------------------------------------
# Check the Docker container status
# ------------------------------------------------------------------------------
CONTAINER_STATUS=$(docker ps -q -f name=px4_sitl)
if [ -z "$CONTAINER_STATUS" ]; then
    echo "Error: Simulation Docker container did not start for simulation_config.yaml"
    exit 1
fi

# ------------------------------------------------------------------------------
# Check if the model is spawned in Gazebo
# ------------------------------------------------------------------------------
check_model_spawned "x500" "$CONTAINER_NAME"

# ------------------------------------------------------------------------------
# Check if the PX4 process is running
# ------------------------------------------------------------------------------
check_px4_running "$CONTAINER_NAME"

# ------------------------------------------------------------------------------
# Check if the MicroXRCEAgent process is running
# ------------------------------------------------------------------------------
check_agent_running "$CONTAINER_NAME"

# ------------------------------------------------------------------------------
# Run the launch_simulation.sh script with the second configuration file
# ------------------------------------------------------------------------------
$SCRIPT_DIR/../tools/docker_scripts/launch_simulation.sh -f $CONFIG_FILE_2 -a -b main
check_result $? "launch_simulation.sh with simulation_config_custom.yaml"

# ------------------------------------------------------------------------------
# Check the Docker container status
# ------------------------------------------------------------------------------
CONTAINER_STATUS=$(docker ps -q -f name=px4_sitl)
if [ -z "$CONTAINER_STATUS" ]; then
    echo "Error: Simulation Docker container did not start for simulation_config_custom.yaml"
    exit 1
fi

# ------------------------------------------------------------------------------
# Check if the model is spawned in Gazebo
# ------------------------------------------------------------------------------
check_model_spawned "my_custom_quad" "$CONTAINER_NAME"

# ------------------------------------------------------------------------------
# Check if the PX4 process is running
# ------------------------------------------------------------------------------
check_px4_running "$CONTAINER_NAME"

# ------------------------------------------------------------------------------
# Check if the MicroXRCEAgent process is running
# ------------------------------------------------------------------------------
check_agent_running "$CONTAINER_NAME"

# ------------------------------------------------------------------------------
# Print a message indicating the test passed
# ------------------------------------------------------------------------------
echo "launch_simulation.sh test passed"
