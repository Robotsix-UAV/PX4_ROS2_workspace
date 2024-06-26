### Firmware Utilities Guide

#### Introduction

This guide provides instructions on how to use the firmware scripts to flash PX4 firmware to a device and upload parameters using Docker.

#### Firmware Flashing

The `firmware_upload.sh` script automates the process of setting up the PX4-Autopilot environment, checking out the desired git branch or tag, and flashing the firmware to a specified platform. If no options are provided, the script will ask for the necessary information through prompts.

##### Usage
Your device must be connected to your computer via USB. The script will automatically detect the device and flash the firmware.
```sh
/tools/docker_scripts/firmware_upload.sh
```

##### Options
- `-h` : Show help message and exit
- `-b` : Specify the git branch.
- `-t` : Specify the git tag (latest or custom).
- `-p` : Specify the target platform (e.g., px4_fmu-v6x).
- `-a` : Automatically clone PX4-Autopilot if not found.

##### Examples
```sh
/tools/docker_scripts/firmware_upload.sh -b main -p px4_fmu-v6x -a
/tools/docker_scripts/firmware_upload.sh -t latest -p px4_fmu-v6x -a
```

#### Parameters Upload

The `parameters_upload.sh` script uploads parameters to a PX4 device using Docker.

##### Usage
Your device must be connected to your computer via USB. The script will automatically detect the device and upload the parameters.
```sh
/tools/docker_scripts/parameters_upload.sh -f <path_to_parameter_file>
```

##### Parameter File Structure
The parameter file is a text file containing the parameters to upload. Each line should contain a parameter name and value separated by a space. Float parameters should be written with a decimal point as the type is inferred from the value. <br>
For example:
```
UXRCE_DDS_CFG 1000
EKF2_ABIAS_INIT 0.15
```
See the [PX4 documentation](https://docs.px4.io/main/en/advanced_config/parameter_reference.html) for a list of parameters.

##### Options
- `-h` : Show help message and exit
- `-f` : Specify the parameter file defining the parameters to upload.