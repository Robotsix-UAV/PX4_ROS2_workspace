#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Launch Simulation Script
#
# This script is used to launch a PX4 simulation using the Tmuxinator tool.
# It requires a configuration YAML file as an argument, which specifies the
# simulation world and models to be used.
#
# Usage:
#   ./launch_simulation.sh <configuration_file>
#
# Arguments:
#   <configuration_file> - Path to the configuration YAML file.
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Check if the correct number of arguments is provided
# ------------------------------------------------------------------------------
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <configuration_file>"
    exit 1
fi

# ------------------------------------------------------------------------------
# Set up paths based on the script's directory
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PX4_DIR="$SCRIPT_DIR/../../PX4-Autopilot"
AIRFRAMES_DIR="$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/airframes"

# ------------------------------------------------------------------------------
# Read the configuration file and extract required parameters
# ------------------------------------------------------------------------------
FILE_PATH=$1
HEADLESS=$(yq e '.headless // false' $FILE_PATH)
WORLD=$(yq e '.world' $FILE_PATH)
MODEL_LIST=$(yq e '.models[].name' $FILE_PATH | paste -sd ':' -)
POSES=$(yq e '.models[].pose | join(",")' $FILE_PATH | paste -sd ':' -)

# ------------------------------------------------------------------------------
# Launch the simulation using Tmuxinator with the extracted parameters
# ------------------------------------------------------------------------------
tmuxinator start px4_sitl -p $SCRIPT_DIR/simulation_tmux.yaml \
    PX4_DIR=$PX4_DIR \
    MODEL_LIST=$MODEL_LIST \
    MODEL_POSITIONS=$POSES \
    GZ_WORLD=$WORLD \
    HEADLESS=$HEADLESS
