#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Test Script for parameters_upload.sh
#
# This script is designed to test the functionality of the parameters_upload.sh
# script by running it with a specified parameter file and ensuring it executes
# correctly. It checks if the required parameter file is provided and runs the
# script, verifying the result of the Docker command execution.
#
# Usage:
#   ./test_parameters_upload.sh <parameter_file>
# ==============================================================================

# ------------------------------------------------------------------------------
# Print a message indicating the start of the test
# ------------------------------------------------------------------------------
echo "Running parameters_upload.sh test"

# ------------------------------------------------------------------------------
# Check if the parameter file is provided
# ------------------------------------------------------------------------------
if [ -z "$1" ]; then
    echo "Error: No parameter file provided"
    echo "Usage: $0 <parameter_file>"
    exit 1
fi

# ------------------------------------------------------------------------------
# Get the directory of the script
# ------------------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname "$0"))

# ------------------------------------------------------------------------------
# Run the parameters_upload.sh script with the specified parameter file
# ------------------------------------------------------------------------------
$SCRIPT_DIR/../tools/docker_scripts/parameters_upload.sh -f $1

# ------------------------------------------------------------------------------
# Check if the Docker command ran successfully
# ------------------------------------------------------------------------------
if [ $? -eq 0 ]; then
    echo "parameters_upload.sh test passed"
else
    echo "parameters_upload.sh test failed"
    exit 1
fi
