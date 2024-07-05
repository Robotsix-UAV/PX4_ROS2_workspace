#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Run Simulation Script
#
# This script automates the launch of a simulation for PX4 Autopilot using Docker.
# If no tag or branch is specified, the script will use the current state of the repository if found.
#
# Usage:
#   ./launch_simulation.sh [options]
#
# Options:
#   -h      Show help message and exit
#   -b      Specify the git branch.
#   -t      Specify the git tag (latest or custom). If 'latest' is specified, the latest release tag will be checked out.
#   -a      Automatically clone PX4-Autopilot if not found.
#   -f      Specify the configuration file for the simulation.
#
# Example:
#   ./launch_simulation.sh -b main -f config.yaml -a
#   ./launch_simulation.sh -t latest -f config.yaml -a
# ==============================================================================

# ------------------------------------------------------------------------------
# Function to display the help message
# ------------------------------------------------------------------------------
show_help() {
    echo -e "Usage: $0 [-h] [-b branch] [-t tag] [-f configuration_file]"
    echo -e "  -h   Display this help message."
    echo -e "  -b   Specify the git branch."
    echo -e "  -t   Specify the git tag (latest or custom). If 'latest' is specified, the latest release tag will be checked out."
    echo -e "  -a   Automatically clone PX4-Autopilot if not found."
    echo -e "  -f   Specify the configuration file for the simulation."
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
# Check the dependency nvidia-container-runtime required for the SITL simulation
# ------------------------------------------------------------------------------
if ! docker info | grep -q "nvidia"; then
    echo -e "${RED}nvidia-container-runtime is not installed. Aborting.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Parse command-line options
# ------------------------------------------------------------------------------
while getopts "hb:t:f:a" opt; do
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
    f)
        config_file=${OPTARG}
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
# Check if configuration file is provided
# ------------------------------------------------------------------------------
if [ -z "${config_file}" ]; then
    echo -e "${RED}Configuration file not specified. Use -f option to provide the file.${NC}"
    show_help
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
    echo -e "${RED}Failed to clone or checkout PX4-Autopilot. Aborting.${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Copy custom airframe files and update CMakeLists.txt
# ------------------------------------------------------------------------------
PX4_DIR=$SCRIPT_DIR/../../PX4-Autopilot
AIRFRAMES_DIR=$SCRIPT_DIR/../../gz_sim/custom_airframes
FILE="$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/airframes/CMakeLists.txt"
TEMP_FILE="CMakeLists.tmp"
index=1

while IFS= read -r line; do
    if [[ "$line" == ")" ]]; then
        for dir in $AIRFRAMES_DIR/*; do
            if [ -d "$dir" ]; then
                if [ -f "$dir/$(basename $dir)" ]; then
                    if [ -d "$PX4_DIR/Tools/simulation/gz/models/$(basename $dir)" ]; then
                        rm -rf "$PX4_DIR/Tools/simulation/gz/models/$(basename $dir)"
                    fi
                    cp -rf "$dir" "$PX4_DIR/Tools/simulation/gz/models/$(basename $dir)"
                    config_name="666${index}_$(basename $dir)"
                    if ! grep -q "$(basename $dir)" "$FILE"; then
                        echo "$config_name" >>$TEMP_FILE
                    else
                        # Replace the existing line with the new configuration number
                        sed -i "s/[0-9]+_$(basename $dir)/$config_name/g" $TEMP_FILE
                    fi
                    cp -r "$dir/$(basename $dir)" "$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/airframes/$config_name"
                    index=$((index + 1))
                fi
            fi
        done
    fi
    echo "$line" >>$TEMP_FILE
done <$FILE

mv $TEMP_FILE $FILE

# ------------------------------------------------------------------------------
# Copy custom world files to the PX4-Autopilot directory
# ------------------------------------------------------------------------------
WORLD_DIR=$SCRIPT_DIR/../../gz_sim/custom_worlds
for file in $WORLD_DIR/*; do
    if [ -f "$file" ]; then
        cp -rf "$file" "$PX4_DIR/Tools/simulation/gz/worlds/$(basename $file)"
    fi
done

# ------------------------------------------------------------------------------
# Docker command to build SITL firmware
# ------------------------------------------------------------------------------
DOCKER_REPO=robotsix/px4_sitl_builder:main
docker pull $DOCKER_REPO
docker run --rm -w "$SCRIPT_DIR" -v $SCRIPT_DIR/../../PX4-Autopilot:$SCRIPT_DIR/../../PX4-Autopilot:rw -v $SCRIPT_DIR/../scripts:$SCRIPT_DIR:ro $DOCKER_REPO bash -c "./sitl_build.sh"

# ------------------------------------------------------------------------------
# Docker command to run the simulation
# ------------------------------------------------------------------------------
DOCKER_REPO=robotsix/gz_sim:main
docker pull $DOCKER_REPO
if [ "$(docker ps -q -f name=px4_sitl)" ]; then
    docker stop px4_sitl
fi

# ------------------------------------------------------------------------------
# Run the container with the NVIDIA runtime
# ------------------------------------------------------------------------------
CONFIG_DIR=$(readlink -f $(dirname "$config_file"))
CONFIG_FILE=$(basename "$config_file")
xhost + && docker run -it -d --rm --name px4_sitl --runtime=nvidia \
    -v /tmp/.X11-unix:/tmp/.X11-unix -v /dev/dri:/dev/dri \
    -w "$SCRIPT_DIR" -v $SCRIPT_DIR/../../PX4-Autopilot:$SCRIPT_DIR/../../PX4-Autopilot:rw \
    -v $SCRIPT_DIR/../scripts:$SCRIPT_DIR:ro \
    -v $CONFIG_DIR:/configurations:ro \
    -e DISPLAY=$DISPLAY \
    $DOCKER_REPO bash -c "./launch_simulation.sh /configurations/$CONFIG_FILE"
