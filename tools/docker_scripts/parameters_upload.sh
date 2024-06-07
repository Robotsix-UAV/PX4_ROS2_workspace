#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# PX4 Parameters Upload Script
#
# This script uploads parameters to a PX4 device using Docker. It ensures the
# specified parameter file is valid and accessible, sets up the necessary
# environment, and runs the Docker command to perform the upload.
#
# Usage:
#   ./parameters_upload.sh [options]
#
# Options:
#   -h       Show help message and exit
#   -f       Specify the parameter file defining the parameters to upload
#
# Example:
#   ./parameters_upload.sh -f params.txt
# ==============================================================================

# ------------------------------------------------------------------------------
# Function to display the help message
# ------------------------------------------------------------------------------
show_help() {
    echo -e "Usage: $0 [-h] -f parameter_file"
    echo -e "  -h   Display this help message."
    echo -e "  -f   Specify the parameter file defining the parameters to upload."
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
        param_file=${OPTARG}
        ;;
    \?)
        echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
        exit 1
        ;;
    esac
done

# ------------------------------------------------------------------------------
# Ensure required commands are available
# ------------------------------------------------------------------------------
command -v docker >/dev/null 2>&1 || {
    echo -e "${RED}docker is not installed. Aborting.${NC}"
    exit 1
}

# ------------------------------------------------------------------------------
# Check if parameter file is provided
# ------------------------------------------------------------------------------
if [ -z "${param_file}" ]; then
    echo -e "${RED}Parameter file not specified. Use -f option to provide the file.${NC}"
    show_help
    exit 1
fi

# ------------------------------------------------------------------------------
# Check if parameter file exists
# ------------------------------------------------------------------------------
if [ ! -f "${param_file}" ]; then
    echo -e "${RED}Parameter file not found: ${param_file}${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Set up necessary directories and variables
# ------------------------------------------------------------------------------
PARAM_DIR=$(readlink -f $(dirname "$param_file"))
PARAM_FILE=$(basename "$param_file")
SCRIPT_DIR=$(readlink -f $(dirname "$0"))
DOCKER_REPO=robotsix/pymavlink:main

# ------------------------------------------------------------------------------
# Pull the Docker image and run the command to upload parameters
# ------------------------------------------------------------------------------
docker pull $DOCKER_REPO
docker run --rm -w "$SCRIPT_DIR" -v "$SCRIPT_DIR/../scripts:$SCRIPT_DIR:ro" -v "$PARAM_DIR:/param_dir:ro" --privileged -v /dev:/dev:rw $DOCKER_REPO python3 parameters_upload.py --file /param_dir/$PARAM_FILE
