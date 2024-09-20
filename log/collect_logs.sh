#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Drone Log Collection Script
#
# This script collects log files from multiple drones specified as a comma-separated
# list in the format "user@ip". It connects to each drone using SSH, retrieves the 
# UAV name, creates a local directory based on the UAV name, and synchronizes the 
# logs from the remote machine to the local directory using rsync.
#
# Usage:
#   ./collect_logs.sh "user1@ip1,user2@ip2,..."
#
# Arguments:
#   DRONES   Comma-separated list of drones in 'user@ip' format.
#
# Example:
#   ./collect_logs.sh "user1@192.168.1.101,user2@192.168.1.102"
# ==============================================================================
 
# ------------------------------ #
#        Configuration           #
# ------------------------------ #
# Define the remote log directory for all drones.
REMOTE_LOG_DIR="~/uav_ws/log"

# Define the local base directory where the logs will be stored.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BASE_DIR="$SCRIPT_DIR"

# ------------------------------ #
#         Functions              #
# ------------------------------ #

# ------------------------------------------------------------------------------
# Function to print an error message and exit the script.
# Usage: error_exit <error_message>
# ------------------------------------------------------------------------------
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Function to display usage instructions for the script.
# This function provides a detailed explanation of how to use the script.
# ------------------------------------------------------------------------------
usage() {
    echo "Usage: $0 \"user1@ip1,user2@ip2,...\""
    echo ""
    echo "Description:"
    echo "  Collects logs from multiple drones specified as a comma-separated list."
    echo ""
    echo "Arguments:"
    echo "  DRONES   Comma-separated list of drones in 'user@ip' format."
    echo ""
    echo "Examples:"
    echo "  $0 \"user1@192.168.1.101,user2@192.168.1.102,user3@192.168.1.103\""
    echo ""
    echo "Each drone should be specified in the 'user@ip' format, separated by commas."
    exit 1
}

# ------------------------------------------------------------------------------
# Function to validate if a given string is a valid IPv4 address.
# This checks whether the IP address is in the correct format and each octet
# is within the valid range (0-255).
# ------------------------------------------------------------------------------
is_valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Split the IP into its four octets.
        IFS='.' read -r -a octets <<< "$ip"
        # Validate each octet.
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                return 1
            fi
        done
        stat=0
    fi
    return $stat
}

# ------------------------------------------------------------------------------
# Function to collect logs from a single drone.
# It connects via SSH, retrieves the UAV name, and synchronizes the logs.
# Arguments:
#   $1 - The drone's user@ip format string.
#   $2 - The index of the drone in the list (for identification purposes).
# ------------------------------------------------------------------------------
collect_logs() {
    local USER_AT_IP="$1"
    local INDEX="$2"

    # Extract username and IP address from the string.
    IFS='@' read -r USERNAME IP_ADDRESS <<< "$USER_AT_IP"

    # Validate the extracted username and IP address.
    if [[ -z "$USERNAME" || -z "$IP_ADDRESS" ]]; then
        echo "Invalid drone format at index $INDEX: $USER_AT_IP. Expected format 'user@ip'. Skipping..." >&2
        return
    fi

    echo "Processing drone [Index: $INDEX]: $USERNAME@$IP_ADDRESS"

    # Step 1: Retrieve the UAV_NAME from the remote machine via SSH.
    echo "Connecting to $USERNAME@$IP_ADDRESS to retrieve UAV_NAME..."
    UAV_NAME=$(ssh -o BatchMode=yes "${USERNAME}@${IP_ADDRESS}" 'bash -c "source ~/.bashrc_offboard; echo \$UAV_NAME"')

    # If SSH connection fails, log an error and skip this drone.
    if [ $? -ne 0 ]; then
        echo "Failed to connect to $USERNAME@$IP_ADDRESS. Skipping..." >&2
        echo "----------------------------------------"
        return
    fi

    # Validate the retrieved UAV_NAME.
    if [ -z "$UAV_NAME" ]; then
        echo "UAV_NAME is not set on $USERNAME@$IP_ADDRESS or could not be retrieved. Skipping..." >&2
        echo "----------------------------------------"
        return
    fi

    echo "UAV_NAME retrieved: $UAV_NAME"

    # Step 2: Create the local directory for storing logs, based on UAV_NAME.
    LOCAL_LOG_DIR="$LOCAL_BASE_DIR/$UAV_NAME"

    if [ ! -d "$LOCAL_LOG_DIR" ]; then
        echo "Creating local directory: $LOCAL_LOG_DIR"
        mkdir -p "$LOCAL_LOG_DIR" || { echo "Failed to create local directory: $LOCAL_LOG_DIR. Skipping..." >&2; echo "----------------------------------------"; return; }
    else
        echo "Local directory already exists: $LOCAL_LOG_DIR"
    fi

    # Step 3: Synchronize logs from the remote directory to the local directory.
    echo "Starting to synchronize logs from $USERNAME@$IP_ADDRESS..."
    rsync -avz --progress "${USERNAME}@${IP_ADDRESS}:${REMOTE_LOG_DIR}/" "$LOCAL_LOG_DIR/" \
        || { echo "rsync failed for $USERNAME@$IP_ADDRESS. Skipping..." >&2; echo "----------------------------------------"; return; }

    echo "Logs have been successfully copied to $LOCAL_LOG_DIR"
    echo "----------------------------------------"
}

# ------------------------------ #
#        Main Execution          #
# ------------------------------ #

# Ensure exactly one argument is provided (the drone list).
if [ "$#" -ne 1 ]; then
    echo "Incorrect number of arguments."
    usage
fi

# Read the argument: comma-separated list of drones.
DRONE_LIST_ARG="$1"

# Ensure the argument is not empty.
if [[ -z "$DRONE_LIST_ARG" ]]; then
    error_exit "Drone list argument is empty."
fi

# Split the drone list into an array using comma as the delimiter.
IFS=',' read -r -a DRONES <<< "$DRONE_LIST_ARG"

# Ensure at least one drone is specified.
if [ "${#DRONES[@]}" -eq 0 ]; then
    error_exit "No drones specified in the list."
fi

# Display the list of drones to be processed.
echo "Drones to be processed:"
for i in "${!DRONES[@]}"; do
    echo "  [$i] ${DRONES[$i]}"
done
echo "----------------------------------------"

# Loop through each drone in the list and collect logs.
for i in "${!DRONES[@]}"; do
    collect_logs "${DRONES[$i]}" "$i"
done

# Indicate that all tasks are complete.
echo "All log collection tasks completed."
exit 0
