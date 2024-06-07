#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# PX4 Firmware Upload Script
#
# This script automates the process of setting up the PX4-Autopilot environment,
# checking out the desired git branch or tag, and flashing the firmware to a specified platform.
# It ensures the required dependencies are installed, handles directory setup,
# and uses Docker to perform the firmware flashing. The script is designed to be
# user-friendly by providing prompts and options for necessary inputs.
# If no tag or branch is specified, the script will use the current state of the repository if found.
#
# Usage:
#   ./firmware_upload.sh [options]
#
# Options:
#   -h      Show help message and exit
#   -b      Specify the git branch.
#   -t      Specify the git tag (latest or custom). If 'latest' is specified, the latest release tag will be checked out.
#   -p      Specify the target platform (e.g., px4_fmu-v6x).
#   -a      Automatically clone PX4-Autopilot if not found
#
# Example:
#   ./firmware_upload.sh -b main -p px4_fmu-v6x -a
#   ./firmware_upload.sh -t latest -p px4_fmu-v6x -a
# ==============================================================================

# ------------------------------------------------------------------------------
# Function to display the help message
# ------------------------------------------------------------------------------
show_help() {
    echo -e "Usage: $0 [-h] [-b branch] [-t tag] [-p platform] [-a]"
    echo -e "  -h   Display this help message."
    echo -e "  -b   Specify the git branch."
    echo -e "  -t   Specify the git tag (latest or custom). If 'latest' is specified, the latest release tag will be checked out."
    echo -e "  -p   Specify the target platform (e.g., px4_fmu-v6x)."
    echo -e "  -a   Automatically clone PX4-Autopilot if not found."
    echo -e "If no options are given, the script will prompt for necessary inputs."
    echo -e "If no tag or branch is specified, the script will use the current state of the repository if found."
}

# ------------------------------------------------------------------------------
# Define ANSI color codes for output formatting
# ------------------------------------------------------------------------------
RED='\033[0;31m'
NC='\033[0m' # No Color

auto_clone=false

# ------------------------------------------------------------------------------
# Ensure required commands are available
# ------------------------------------------------------------------------------
command -v docker >/dev/null 2>&1 || {
    echo -e "${RED}docker is not installed. Aborting.${NC}"
    exit 1
}

# ------------------------------------------------------------------------------
# Parse command-line options
# ------------------------------------------------------------------------------
while getopts "hb:t:p:a" opt; do
    case ${opt} in
    h)
        show_help
        exit 0
        ;;
    b)
        branch=${OPTARG}
        ;;
    t)
        tag=${OPTARG}
        ;;
    p)
        platform=${OPTARG}
        ;;
    a)
        auto_clone=true
        ;;
    \?)
        echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
        exit 1
        ;;
    esac
done

# ------------------------------------------------------------------------------
# Check if both branch and tag are defined
# ------------------------------------------------------------------------------
if [ -n "${branch}" ] && [ -n "${tag}" ]; then
    echo -e "${RED}Error: Both branch and tag cannot be specified simultaneously.${NC}" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Clone the PX4-Autopilot repository using the clone_PX4.sh script
# ------------------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname "$0"))

# If the repository exists and no branch or tag is specified, skip cloning
if [ -d "$SCRIPT_DIR/../../PX4-Autopilot" ] && [ -z "$branch" ] && [ -z "$tag" ]; then
    echo -e "${RED}Using existing PX4-Autopilot repository.${NC}"
else
    if $auto_clone; then
        if [ -n "$branch" ]; then
            $SCRIPT_DIR/../scripts/clone_PX4.sh -a -b $branch
        elif [ -n "$tag" ]; then
            $SCRIPT_DIR/../scripts/clone_PX4.sh -a -t $tag
        else
            $SCRIPT_DIR/../scripts/clone_PX4.sh -a
        fi
    else
        if [ -n "$branch" ]; then
            $SCRIPT_DIR/../scripts/clone_PX4.sh -b $branch
        elif [ -n "$tag" ]; then
            $SCRIPT_DIR/../scripts/clone_PX4.sh -t $tag
        else
            $SCRIPT_DIR/../scripts/clone_PX4.sh
        fi
    fi
fi

# ------------------------------------------------------------------------------
# Verify the cloning process was successful
# ------------------------------------------------------------------------------
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to clone PX4-Autopilot. Aborting.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Prompt for the target platform if not provided
# ------------------------------------------------------------------------------
if [ -z "${platform}" ]; then
    echo -e -n "${RED}Enter the target platform to flash the firmware (e.g., px4_fmu-v6x): ${NC}"
    read platform
fi

# ------------------------------------------------------------------------------
# Pull the Docker image and flash the firmware using Docker
# ------------------------------------------------------------------------------
DOCKER_REPO=robotsix/px4_fw_upload:main
docker pull $DOCKER_REPO
docker run --rm -w "$SCRIPT_DIR" -v $SCRIPT_DIR/../../PX4-Autopilot:$SCRIPT_DIR/../../PX4-Autopilot:rw -v $SCRIPT_DIR/../scripts:$SCRIPT_DIR:ro --privileged -v /dev:/dev:rw $DOCKER_REPO bash -c "./firmware_upload.sh $platform"
