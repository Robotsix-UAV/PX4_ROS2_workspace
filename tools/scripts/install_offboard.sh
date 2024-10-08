#!/bin/bash

# ==============================================================================
# ROS2 UAV PX4 Setup Script with Optional Local Docker Registry and Micro XRCE-DDS Agent Arguments
#
# This script automates the setup of the ROS2 environment for UAV control using Docker and systemd services.
# It accepts optional arguments to specify a local Docker registry IP and port for pulling images,
# and custom arguments for the Micro XRCE-DDS Agent.
#
# Usage:
#   ./install_offboard.sh [-r local_registry_ip:port] [-a "agent_args"] uav_name
# ==============================================================================

# ------------------------------------------------------------------------------
# Check if the script is being run as root
# ------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# ------------------------------------------------------------------------------
# Get the user's home directory
# ------------------------------------------------------------------------------
USER_HOME=$(eval echo /home/${SUDO_USER})

# ------------------------------------------------------------------------------
# Initialize variables with default values
# ------------------------------------------------------------------------------
REGISTRY="robotsix"
MICRO_AGENT_ARGS=""

# ------------------------------------------------------------------------------
# Parse options
# ------------------------------------------------------------------------------
while getopts ":r:a:h" opt; do
  case ${opt} in
    r )
      REGISTRY=$OPTARG
      ;;
    a )
      MICRO_AGENT_ARGS=$OPTARG
      ;;
    h )
      echo "Usage: ./install_offboard.sh [-r local_registry_ip:port] [-a \"agent_args\"] uav_name"
      exit 0
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: ./install_offboard.sh [-r local_registry_ip:port] [-a \"agent_args\"] uav_name"
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument." >&2
      echo "Usage: ./install_offboard.sh [-r local_registry_ip:port] [-a \"agent_args\"] uav_name"
      exit 1
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Shift parsed options
# ------------------------------------------------------------------------------
shift $((OPTIND -1))

# ------------------------------------------------------------------------------
# Get the UAV name
# ------------------------------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "Usage: ./install_offboard.sh [-r local_registry_ip:port] [-a \"agent_args\"] uav_name"
    exit 1
fi

UAV_NAME=$1

# ------------------------------------------------------------------------------
# Set Docker image names, prefixed with local registry if provided
# ------------------------------------------------------------------------------
DOCKER_IMAGE_UAV="$REGISTRY/ros2_uav_px4:main"
DOCKER_IMAGE_AGENT="$REGISTRY/micro_dds_agent:main"

# ------------------------------------------------------------------------------
# Pull the Docker image for ROS2 UAV PX4
# ------------------------------------------------------------------------------
docker pull --platform linux/arm64 $DOCKER_IMAGE_UAV

# ------------------------------------------------------------------------------
# Set up configuration files by copying them from the Docker container to the local workspace
# ------------------------------------------------------------------------------
mkdir -p $USER_HOME/uav_ws  # Create UAV workspace directory if it doesn't exist
mkdir -p $USER_HOME/uav_ws/log  # Create logs directory for the UAV
docker run --rm -it -d --name ros2_uav_px4_cont $DOCKER_IMAGE_UAV  # Start the Docker container
docker cp ros2_uav_px4_cont:/ros_ws/install/ros2_uav_parameters/share/ros2_uav_parameters/config $USER_HOME/uav_ws
docker stop ros2_uav_px4_cont  # Stop the temporary container

# ------------------------------------------------------------------------------
# Create a systemd service file for managing the ROS2 offboard Docker container
# ------------------------------------------------------------------------------
cat << EOF > /etc/systemd/system/ros2_offboard.service
[Unit]
Description=Offboard ROS2 Docker
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker run --rm -it -d --name ros2_uav_offboard --network host -v $USER_HOME/uav_ws/config:/ros_ws/install/ros2_uav_parameters/share/ros2_uav_parameters/config -v $USER_HOME/uav_ws/log:/ros_ws/log $DOCKER_IMAGE_UAV
ExecStop=/usr/bin/docker stop ros2_uav_offboard

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------------------------
# Enable and start the systemd service for the ROS2 offboard Docker container
# ------------------------------------------------------------------------------
systemctl daemon-reload  # Reload systemd to recognize the new service
systemctl enable ros2_offboard.service  # Enable the service to start on boot
systemctl start ros2_offboard.service   # Start the service immediately

# ------------------------------------------------------------------------------
# List available launch files from the ROS2 UAV PX4 Docker container
# ------------------------------------------------------------------------------
sleep 2  # Wait for the Docker container to start
LAUNCH_LIST=$(docker exec ros2_uav_offboard ls /ros_ws/install/ros2_uav_px4/share/ros2_uav_px4/launch)
echo "Available launch files:"
echo "$LAUNCH_LIST"

# ------------------------------------------------------------------------------
# Create ~/.bashrc_offboard
# ------------------------------------------------------------------------------
echo "UAV_NAME=$UAV_NAME" > $USER_HOME/.bashrc_offboard

# Define the shutdown_tmux_window function
cat << 'EOF' >> $USER_HOME/.bashrc_offboard

shutdown_tmux_window() {
    local session="$1"
    local window="$2"
    local docker_container="$3"
    local timeout=30  # Total timeout in seconds
    local interval=1  # Interval between checks in seconds

    if [ -z "$session" ] || [ -z "$window" ] || [ -z "$docker_container" ]; then
        echo "Usage: shutdown_tmux_window <session> <window> <docker_container>"
        return 1
    fi

    echo "Attempting to gracefully terminate processes in tmux window '$window' of session '$session'..."

    # Send Ctrl-C to the specified tmux window
    docker exec "$docker_container" tmux send-keys -t "${session}:${window}" C-c

    # Initialize elapsed time
    local elapsed=0

    while [ "$elapsed" -lt "$timeout" ]; do
        # Get list of current commands in all panes
        current_commands=$(docker exec "$docker_container" tmux list-panes -t "${session}:${window}" -F '#{pane_current_command}')

        # Flag to determine if any active processes are running
        active_processes=false

        while read -r cmd; do
            if [[ "$cmd" != "bash" && "$cmd" != "zsh" && "$cmd" != "sh" ]]; then
                active_processes=true
                echo "Active process detected in pane: $cmd"
            fi
        done <<< "$current_commands"

        if [ "$active_processes" = false ]; then
            echo "No active processes detected in any panes. Killing tmux window '$window'..."
            docker exec "$docker_container" tmux kill-window -t "${session}:${window}"
            echo "tmux window '$window' has been killed successfully."
            return 0
        else
            sleep "$interval"
            elapsed=$((elapsed + interval))
        fi
    done

    echo "Timeout reached. Some processes are still running. tmux window '$window' was not killed."
    return 1
}
EOF

for LAUNCH_FILE in $LAUNCH_LIST; do
    LAUNCH_FILE_WE=$(echo $LAUNCH_FILE | cut -d'.' -f1)  # Extract the file name without extension
    # Alias to gracefully stop the node
    echo "alias stop_$LAUNCH_FILE_WE='shutdown_tmux_window uav_session $LAUNCH_FILE_WE ros2_uav_offboard'" >> $USER_HOME/.bashrc_offboard

    # Alias to launch the node
    echo "alias launch_$LAUNCH_FILE_WE='if docker exec ros2_uav_offboard tmux list-windows -t uav_session | grep -q $LAUNCH_FILE_WE; then stop_$LAUNCH_FILE_WE; fi; docker exec ros2_uav_offboard bash -c \"source /ros_ws/install/setup.sh && tmux new-window -t uav_session -n $LAUNCH_FILE_WE\" && docker exec ros2_uav_offboard tmux send-keys -t uav_session:$LAUNCH_FILE_WE \"ros2 launch ros2_uav_px4 $LAUNCH_FILE uav_namespace:=\$UAV_NAME\" Enter'" >> $USER_HOME/.bashrc_offboard
done

# Source ~/.bashrc_offboard in ~/.bashrc if it's not already sourced
if ! grep -q ".bashrc_offboard" $USER_HOME/.bashrc; then
    echo "source $USER_HOME/.bashrc_offboard" >> $USER_HOME/.bashrc
fi

# ------------------------------------------------------------------------------
# Pull the Docker image for microDDS agent
# ------------------------------------------------------------------------------
docker pull --platform linux/arm64 $DOCKER_IMAGE_AGENT

# ------------------------------------------------------------------------------
# Start the microDDS agent as a systemd service with optional custom arguments
# ------------------------------------------------------------------------------
cat << EOF > /etc/systemd/system/microxrceagent.service
[Unit]
Description=Micro XRCE-DDS Agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/docker run --rm -it -d --name microxrceagent --network host --entrypoint /usr/local/bin/MicroXRCEAgent $DOCKER_IMAGE_AGENT $MICRO_AGENT_ARGS
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable microxrceagent.service
systemctl start microxrceagent.service
