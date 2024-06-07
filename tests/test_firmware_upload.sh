#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Test Script for firmware_upload.sh
#
# This script is designed to test the functionality of the firmware_upload.sh
# script by running it with different parameters and ensuring it executes
# correctly. It checks the result of each execution and exits if any command
# fails. The script tests the firmware upload process for the 'main' branch
# and the 'latest' tag and performs cleanup using a Docker container.
#
# Usage:
#   ./test_firmware_upload.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# Print a message indicating the start of the test
# ------------------------------------------------------------------------------
echo "Running firmware_upload.sh test"

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
# Function to clean up the test environment
# ------------------------------------------------------------------------------
cleanup() {
    echo "Cleaning up"
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
# Run the firmware_upload.sh script for the 'main' branch
# ------------------------------------------------------------------------------
$SCRIPT_DIR/../tools/docker_scripts/firmware_upload.sh -b main -p px4_fmu-v6x -a
check_result $? "firmware_upload.sh for main branch"

# ------------------------------------------------------------------------------
# Run the firmware_upload.sh script for the 'latest' tag
# ------------------------------------------------------------------------------
$SCRIPT_DIR/../tools/docker_scripts/firmware_upload.sh -t latest -p px4_fmu-v6x -a
check_result $? "firmware_upload.sh for latest tag"

# ------------------------------------------------------------------------------
# Print a message indicating the test passed
# ------------------------------------------------------------------------------
echo "firmware_upload.sh test passed"
