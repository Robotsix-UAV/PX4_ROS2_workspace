#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Gazebo Simulation Checker Script
#
# This script continuously checks if the Gazebo simulator is running. It waits
# for the simulator to start by checking for a specific process and provides
# feedback to the user once the simulator is up and running.
#
# Usage:
#   ./wait_for_gz_sim.sh
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Function to check if Gazebo simulator is running
# ------------------------------------------------------------------------------
check_gz_sim() {
    pgrep "ruby" >/dev/null 2>&1
    return $?
}

# ------------------------------------------------------------------------------
# Loop until the Gazebo simulator is running
# ------------------------------------------------------------------------------
until check_gz_sim; do
    echo "Waiting for Gazebo simulator to start..."
    sleep 2
done

echo "Gazebo simulator is up!"
