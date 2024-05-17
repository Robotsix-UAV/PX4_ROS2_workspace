### Simulation Guide

#### Introduction

This guide provides instructions on how to use the simulation scripts to generate airframe models and launch simulations for PX4 Autopilot with Gazebo using Docker.

#### Generate Airframe Model

##### Description

The PX4 repository contains models for various airframes. However, you may need to create a custom airframe model for your vehicle. The `generate_airframe.sh` script generates a model for a multirotor vehicle based on configurations provided in a YAML file.

It will generate a `.sdf` file for the airframe model, which can be used in Gazebo simulations already containing the plugins required for PX4 SITL simulation.

It will also generate a configuration file for the airframe model, which can be used to specify the vehicle parameters in the PX4 firmware.

The generated airframe model will be saved in the `gz_sim/custom_airframes` directory. The model visuals are very basic, but you can modify the generated `.sdf` file to provide your own meshes afterward.

##### Usage
```sh
./generate_airframe.sh -f <path_to_yaml_file>
```

##### YAML Configuration Structure
```yaml
model_name: "model_name"
arm_length: 1.0 # in meters
num_motors: 4 # Should be at least 2 and even
angle_offset: 45 # in degrees
weight: 1.0 # in kg
Ixx: 0.03 # in kg*m^2
Iyy: 0.03 # in kg*m^2
Izz: 0.03 # in kg*m^2
max_motor_thrust: 10.0 # in N
first_motor_cw: true  # Optional, defaults to True
```
`angle_offset` is the angle between the first motor and the x-axis to use when no motor is aligned with the x-axis of the UAV.  
`first_motor_cw` specifies if the first motor rotates clockwise. If not specified, it defaults to `True`. The motors will be alternatively clockwise and counterclockwise.

##### Options
- `-h` : Show help message and exit
- `-f` : Specify the configuration file to use

#### Simulation with Gazebo

The `launch_simulation.sh` script automates the launch of a simulation for PX4 Autopilot with Gazebo using Docker.

##### Usage
```sh
./launch_simulation.sh -f <path_to_yaml_file>
```

##### YAML Configuration Structure
```yaml
headless: false
world: default
models:
  - name: gz_x500
    pose: [0, 0, 0, 0, 0, 0]
  - name: gz_x500
    pose: [2, 0, 0, 0, 0, 0]
```
`headless` specifies whether to run the simulation in headless mode. If not specified, it defaults to `False`.
`world` specifies the world file to use for the simulation. Any world of the [PX4 repository](https://github.com/PX4/PX4-gazebo-models/tree/main/worlds) or any custom world in the `gz_sim/custom_worlds` directory can be used.
`models` is a list of models to spawn in the simulation. Each model has a `name` and a `pose` in the format `[x, y, z, roll, pitch, yaw]`. Any model of the [PX4 repository](https://github.com/PX4/PX4-gazebo-models/tree/main/models) or any custom model in the `gz_sim/custom_airframes` directory can be used.

##### Options
- `-h` : Show help message and exit
- `-b` : Specify the git branch of the PX4-Autopilot repository.
- `-t` : Specify the git tag (latest or custom) of the PX4-Autopilot repository.
- `-f` : Specify the configuration file for the simulation.
- `-a` : Automatically clone PX4-Autopilot repository if not found.

Both `-b` and `-t` options cannot be used at the same time. If neither is provided, the script will use the current branch of the PX4-Autopilot repository.