# Holybro Pixhawk Jetson Baseboard setup

## Recovery Mode Setup

- Locate the DIP switch on the baseboard for entering recovery mode.
![DIP Switch Recovery Mode](https://docs.holybro.com/~gitbook/image?url=https%3A%2F%2F2367252986-files.gitbook.io%2F%7E%2Ffiles%2Fv0%2Fb%2Fgitbook-x-prod.appspot.com%2Fo%2Fspaces%252FLIgtGDAvVGkCKGOJb1bR%252Fuploads%252F3OV1ODpUhk3RJ04U8Fl9%252Fimage.png%3Falt%3Dmedia%26token%3Dfaa581b9-0c08-47bc-95da-4dd643a1c481&width=300&dpr=1&quality=100&sign=b002480a&sv=1)

## Connect USB

Connect USB to flash the Jetson Board.
![Connect USB](https://docs.holybro.com/~gitbook/image?url=https%3A%2F%2F2367252986-files.gitbook.io%2F%7E%2Ffiles%2Fv0%2Fb%2Fgitbook-x-prod.appspot.com%2Fo%2Fspaces%252FLIgtGDAvVGkCKGOJb1bR%252Fuploads%252F2nRPtcWBtR7krSQiitPX%252FCleanShot%25202024-05-31%2520at%252018.27.04.png%3Falt%3Dmedia%26token%3Df726c613-9426-459c-884a-de7a45d17a27&width=300&dpr=4&quality=100&sign=4a9c43e1&sv=1)

## Install Jetson OS

- Install the OS following the guide at [NVIDIA's Installation Guide](https://docs.nvidia.com/sdk-manager/install-with-sdkm-jetson/index.html) (skip SDK Components).
- Power the Jetson through the 12V power and the Autopilot through the USB-C port near the ethernet port. **Warning: the Jetson and the Pixhawk Autopilot have each their own power supply. Both should be connected to have the system working properly.**
- Set up the Ethernet connection directly on the Jetson. Keyboard, mouse, and monitor are required for this step.

## Run the Install Offboard Script for ROS2_UAV_PX4
- Install Docker using the steps at [Docker Installation](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository).
- To use Docker as a non-root user, follow the steps at [Post-installation steps for Linux](https://docs.docker.com/engine/install/linux-postinstall/).
- Install cmake

```bash
sudo apt-get install cmake
```

- Download and run the installation script:

```bash
wget https://raw.githubusercontent.com/Robotsix-UAV/PX4_ROS2_workspace/main/tools/scripts/install_offboard.sh
chmod +x install_offboard.sh
sudo ./install_offboard.sh *uav_name*
```

Replace *uav_name* with your specific UAV's name.

## Configure the microDDS Client on the PX4 Autopilot

- Set the parameter 'UXR_DDS_CFG' to 'Disabled' to avoid automatic start of the microDDS client (does not support namespaces).
- Set the microDDS client via the mavlink shell:

```bash
mkdir /fs/microsd/etc
echo "uxrce_dds_client start -t udp -p 8888 -h *Jetson IP* -n *uav_name*" >> /fs/microsd/etc/extras.txt
```

Replace *uav_name* and *Jetson IP* with your specific UAV's name and the Jetson's IP address.
Do not forget to compile the PX4 firmware with the appropriate microDDS configuration. If you use the [firmware flashing utility](https://robotsix-uav.github.io/PX4_ROS2_workspace/firmware/) from the PX4_ROS2_workspace, the firmware will be compiled with the correct configuration.

## Usage

The installation script generate convenient aliases to start the nodes. They are in the `~/.bashrc` file. After installation you need to source the `~/.bashrc` file to use the aliases (or restart the terminal).
All launch files from [ros2_uav_px4](https://github.com/Robotsix-UAV/ros2_uav_px4) get aliases through the installation script.

- To start the offboard modes:

```bash
launch_offboard_modes
```

The script execute the launch file on the docker container 'ros2_uav_offboard'. Proper execution of the nodes can be checked by running:

```bash
docker attach ros2_uav_offboard
```
