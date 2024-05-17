#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Test Script for generate_airframe.sh
#
# This script is designed to test the functionality of the generate_airframe.sh
# script by running it with a sample YAML configuration file and ensuring it
# executes correctly. It checks the result of each execution and exits if any
# command fails. Additionally, it verifies the presence of the generated files.
#
# Usage:
#   ./test_generate_airframe.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# Print a message indicating the start of the test
# ------------------------------------------------------------------------------
echo "Running generate_airframe.sh test"

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
# Function to check if a directory exists and exit if it doesn't
# ------------------------------------------------------------------------------
check_dir_exists() {
    if [ ! -d "$1" ]; then
        echo "Error: $2 not found"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Get the directory of the script
# ------------------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname "$0"))

# ------------------------------------------------------------------------------
# Define the path to the sample YAML configuration file
# ------------------------------------------------------------------------------
CONFIG_FILE="$SCRIPT_DIR/sample_params.yaml"

# ------------------------------------------------------------------------------
# Create a sample YAML configuration file
# ------------------------------------------------------------------------------
cat <<EOF >$CONFIG_FILE
model_name: "test_model"
arm_length: 1.0
num_motors: 4
angle_offset: 45
weight: 1.0
Ixx: 0.03
Iyy: 0.03
Izz: 0.03
max_motor_thrust: 10.0
first_motor_cw: true
EOF

# ------------------------------------------------------------------------------
# Run the generate_airframe.sh script with the sample YAML configuration file
# ------------------------------------------------------------------------------
$SCRIPT_DIR/../tools/docker_scripts/generate_airframe.sh -f $CONFIG_FILE
check_result $? "generate_airframe.sh with sample YAML configuration file"

# ------------------------------------------------------------------------------
# Verify the generated files exist
# ------------------------------------------------------------------------------
TARGET_DIR="$SCRIPT_DIR/../gz_sim/custom_airframes/test_model"

check_file_exists "$TARGET_DIR/model.config" "model.config"
check_file_exists "$TARGET_DIR/model.sdf" "model.sdf"
check_file_exists "$TARGET_DIR/test_model" "px4_init_file"
check_dir_exists "$TARGET_DIR/meshes" "meshes directory"

# ------------------------------------------------------------------------------
# Delete the configuration file
# Clean up the generated model files using the Docker container
# ------------------------------------------------------------------------------
rm -f $CONFIG_FILE
DOCKER_REPO=robotsix/generate_airframe:master
docker run --rm -w "$SCRIPT_DIR" -v $SCRIPT_DIR/..:$SCRIPT_DIR/..:rw $DOCKER_REPO sh -c "rm -rf ../gz_sim/custom_airframes/test_model"
check_result $? "Cleaning up the generated model files with Docker container"

# ------------------------------------------------------------------------------
# Print a message indicating the test passed
# ------------------------------------------------------------------------------
echo "generate_airframe.sh test passed"
