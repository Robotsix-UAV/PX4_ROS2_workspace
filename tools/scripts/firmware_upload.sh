#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# PX4 Firmware Upload Script
#
# This script automates the process of flashing firmware to a specified target
# using the PX4-Autopilot repository. It ensures the required directory setup
# and runs the necessary commands to upload the firmware.
#
# Usage:
#   ./firmware_upload.sh <target>
#
# Arguments:
#   <target> - The target to which the firmware should be uploaded.
#
# Example:
#   ./firmware_upload.sh px4_fmu-v6x
# ==============================================================================

# ------------------------------------------------------------------------------
# Check if a target argument is provided
# ------------------------------------------------------------------------------
if [ -z "$1" ]; then
    echo "Usage: $0 <target>"
    exit 1
fi

# ------------------------------------------------------------------------------
# Change directory to the PX4-Autopilot repository
# ------------------------------------------------------------------------------
cd ../../PX4-Autopilot

# ------------------------------------------------------------------------------
# Set the safe directory to avoid git errors
# ------------------------------------------------------------------------------
git config --global --add safe.directory '*'

# ------------------------------------------------------------------------------
# Run the make command to upload the firmware to the specified target
# ------------------------------------------------------------------------------
make "$1" upload
