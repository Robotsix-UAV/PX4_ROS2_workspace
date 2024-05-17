#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Generate Airframe Script
#
# This script generates model files for a multirotor vehicle based on configurations
# provided in a YAML file.
#
# The YAML configuration file should have the following structure:
#
# model_name: "model_name"
# arm_length: 1.0
# num_motors: 4 # Should be at least 2 and even
# angle_offset: 45
# weight: 1.0
# Ixx: 0.03
# Iyy: 0.03
# Izz: 0.03
# max_motor_thrust: 10.0
# first_motor_cw: true  # Optional, defaults to True
#
# Usage:
#   ./generate_airframe.sh <path_to_yaml_file>
#
# Options:
#   -h       Show help message and exit
#   -f       Specify the configuration file to use
#
# Example:
#   ./generate_airframe.sh -f params.yaml
# ==============================================================================

# ------------------------------------------------------------------------------
# Function to display the help message
# ------------------------------------------------------------------------------
show_help() {
    echo -e "Usage: $0 [-h] -f parameter_file"
    echo -e "  -h   Display this help message."
    echo -e "  -f   Specify the configuration file to use."
}

# ------------------------------------------------------------------------------
# Define ANSI color codes for output formatting
# ------------------------------------------------------------------------------
RED='\033[0;31m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Parse command-line options
# ------------------------------------------------------------------------------
while getopts "hf:" opt; do
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
# Check if configuration file exists
# ------------------------------------------------------------------------------
if [ ! -f "${config_file}" ]; then
    echo -e "${RED}Configuration file not found: ${config_file}${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Ensure required commands are available
# ------------------------------------------------------------------------------
command -v docker >/dev/null 2>&1 || {
    echo -e "${RED}docker is not installed. Aborting.${NC}"
    exit 1
}

# ------------------------------------------------------------------------------
# Set up paths for the configuration file and script directory
# ------------------------------------------------------------------------------
CONFIG_DIR=$(readlink -f $(dirname "$config_file"))
CONFIG_FILE=$(basename "$config_file")
SCRIPT_DIR=$(readlink -f $(dirname "$0"))

# ------------------------------------------------------------------------------
# Docker repository
# ------------------------------------------------------------------------------
DOCKER_REPO=robotsix/generate_airframe:master

# ------------------------------------------------------------------------------
# Pull the Docker image and run the command to generate the airframe
# ------------------------------------------------------------------------------
docker pull $DOCKER_REPO
docker run --rm -w "$SCRIPT_DIR" \
    -v "$SCRIPT_DIR/../scripts:$SCRIPT_DIR:ro" \
    -v "$CONFIG_DIR:/CONFIG_DIR:ro" \
    -v "$SCRIPT_DIR/../../gz_sim:$SCRIPT_DIR/../../gz_sim:rw" \
    $DOCKER_REPO python3 generate_airframe.py /CONFIG_DIR/$CONFIG_FILE
