#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Launch ROS 2 UAV Simulation Script
#
# This script is used to launch ROS 2 UAV simulations using the Tmuxinator tool.
# It requires a configuration YAML file as an argument, which specifies the
# UAV models to be used.
#
# Usage:
#   ./launch_ros2_simulation.sh <configuration_file>
#
# Arguments:
#   <configuration_file> - Path to the configuration YAML file.
# ==============================================================================

# ------------------------------------------------------------------------------
# Check if the correct number of arguments is provided
# ------------------------------------------------------------------------------
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <configuration_file>"
    exit 1
fi

# ------------------------------------------------------------------------------
# Read the configuration file and extract required parameters
# ------------------------------------------------------------------------------
FILE_PATH=$1
MODEL_LIST=$(yq e '.models[].name' $FILE_PATH | paste -sd ':' -)

# ------------------------------------------------------------------------------
# Launch the simulation using Tmuxinator with the extracted parameters
# ------------------------------------------------------------------------------
tmuxinator start ros2_uav_nodes -p simulation_nodes_tmux.yaml MODEL_LIST=$MODEL_LIST
