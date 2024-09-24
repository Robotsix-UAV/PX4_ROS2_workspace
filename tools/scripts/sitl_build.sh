#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# SITL PX4 Firmware build script
#
# This script navigates to the PX4-Autopilot directory, sets the git safe
# directory configuration, and runs the make command to build the firmware.
#
# Usage:
#   ./sitl_build.sh
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Navigate to the PX4-Autopilot directory
# ------------------------------------------------------------------------------
cd ../../PX4-Autopilot

# ------------------------------------------------------------------------------
# Configure Git to consider all directories as safe to avoid errors
# ------------------------------------------------------------------------------
git config --global --add safe.directory '*'

# ------------------------------------------------------------------------------
# Fix the DDS configuration file
# Uncomment the lines
#  # - topic: /fmu/out/vehicle_angular_velocity
#  #   type: px4_msgs::msg::VehicleAngularVelocity
# Also add the lines after the line "publications:" if not found
#  - topic: /fmu/out/vehicle_thrust_setpoint
#    type: px4_msgs::msg::VehicleThrustSetpoint
# ------------------------------------------------------------------------------
sed -i 's/# - topic: \/fmu\/out\/vehicle_angular_velocity/- topic: \/fmu\/out\/vehicle_angular_velocity/' ./src/modules/uxrce_dds_client/dds_topics.yaml
sed -i 's/#   type: px4_msgs::msg::VehicleAngularVelocity/  type: px4_msgs::msg::VehicleAngularVelocity/' ./src/modules/uxrce_dds_client/dds_topics.yaml
if ! grep -q "/fmu/out/vehicle_thrust_setpoint" ./src/modules/uxrce_dds_client/dds_topics.yaml; then
    sed -i '/publications:/a \  - topic: \/fmu\/out\/vehicle_thrust_setpoint\n    type: px4_msgs::msg::VehicleThrustSetpoint' ./src/modules/uxrce_dds_client/dds_topics.yaml
fi

# ------------------------------------------------------------------------------
# Run the make command to build the PX4 SITL
# ------------------------------------------------------------------------------
make px4_sitl
