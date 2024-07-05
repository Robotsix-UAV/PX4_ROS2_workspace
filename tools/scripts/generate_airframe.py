#!/usr/bin/env python3

"""
Copyright 2024 Damien Six (six.damien@robotsix.net)
SPDX-License-Identifier: Apache-2.0

Script to generate model files for a multirotor vehicle using configurations from a YAML file.
The script utilizes Jinja2 templates to create the necessary files and directories for simulation.

Usage:
    python script.py <path_to_yaml_file>

YAML Configuration File Structure:
    model_name: "model_name"
    arm_length: 1.0
    num_motors: 4  # Should be at least 2 and even
    angle_offset: 45
    weight: 1.0
    Ixx: 0.03
    Iyy: 0.03
    Izz: 0.03
    max_motor_thrust: 10.0
    first_motor_cw: true  # Optional, defaults to True

Steps Performed:
1. Read the configuration from the provided YAML file.
2. Validate the number of motors.
3. Calculate motor positions based on the provided arm length and angle offset.
4. Render the Jinja2 templates with the configuration data.
5. Save the generated content to the appropriate files.
6. Copy mesh files from the templates directory to the model directory.
"""

import numpy as np
import os
from os.path import abspath, dirname
from jinja2 import Environment, FileSystemLoader
import yaml
from typing import List, Tuple
import sys

def generate_model_files(arm_length: float, num_motors: int, angle_offset: float, model_name: str, weight: float,
                         Ixx: float, Iyy: float, Izz: float, max_motor_thrust: float, first_motor_cw: bool = True) -> None:
    """
    Generate model files for a multirotor vehicle.

    :param arm_length: Length of the arms of the multirotor.
    :type arm_length: float
    :param num_motors: Number of motors on the multirotor.
    :type num_motors: int
    :param angle_offset: Angle offset for the motors.
    :type angle_offset: float
    :param model_name: Name of the model.
    :type model_name: str
    :param weight: Weight of the model.
    :type weight: float
    :param Ixx: Moment of inertia around the X-axis.
    :type Ixx: float
    :param Iyy: Moment of inertia around the Y-axis.
    :type Iyy: float
    :param Izz: Moment of inertia around the Z-axis.
    :type Izz: float
    :param max_motor_thrust: Maximum thrust of the motors.
    :type max_motor_thrust: float
    :param first_motor_cw: Direction of the first motor (clockwise if True).
    :type first_motor_cw: bool, optional
    :return: None
    :rtype: None
    """
    os.chdir(dirname(abspath(__file__)))
    env = Environment(loader=FileSystemLoader('templates'),
                      trim_blocks=True, lstrip_blocks=True)
    model_config_template = env.get_template('model.config')
    model_sdf_template = env.get_template('model.sdf')
    shell_script_template = env.get_template('px4_init_file')

    target_dir = os.path.join('..', '..', 'gz_sim',
                              'custom_airframes', model_name)
    try:
        os.makedirs(target_dir, exist_ok=False)
    except FileExistsError:
        print("Model directory already exists. Files will be overwritten.")

    if num_motors < 2:
        print("Number of motors should be at least 2. Exiting...")
        return
    if num_motors % 2 != 0:
        print("Number of motors should be even. Exiting...")
        return

    angles = [(angle_offset + i * 360 / num_motors) %
              360 for i in range(num_motors)]
    angles = np.radians(angles)
    motor_positions: List[Tuple[float, float, float]] = [
        (arm_length * np.cos(angle), arm_length * np.sin(angle), 0) for angle in angles]

    model_config_content = model_config_template.render(model_name=model_name)
    model_sdf_content = model_sdf_template.render(
        model_name=model_name,
        num_motors=num_motors,
        arm_length=arm_length,
        motor_positions=motor_positions,
        arm_angles=angles[:num_motors // 2],
        weight=weight,
        Ixx=Ixx,
        Iyy=Iyy,
        Izz=Izz,
        max_motor_thrust=max_motor_thrust,
        first_motor_cw=first_motor_cw
    )

    px4_init_file = shell_script_template.render(
        model_name=model_name,
        motor_positions=motor_positions,
        weight=weight,
        max_motor_thrust=max_motor_thrust,
        num_motors=num_motors,
        first_motor_cw=first_motor_cw
    )

    with open(os.path.join(target_dir, 'model.config'), 'w', encoding='utf-8') as file:
        file.write(model_config_content)

    with open(os.path.join(target_dir, 'model.sdf'), 'w', encoding='utf-8') as file:
        file.write(model_sdf_content)

    with open(os.path.join(target_dir, model_name), 'w', encoding='utf-8') as file:
        file.write(px4_init_file)

    os.system(f"cp -r templates/meshes {target_dir}")

def load_config_and_generate_model(yaml_file: str) -> None:
    """
    Load configuration from a YAML file and generate model files.

    :param yaml_file: Path to the YAML configuration file.
    :type yaml_file: str
    :return: None
    :rtype: None
    """
    with open(yaml_file, 'r', encoding='utf-8') as file:
        config = yaml.safe_load(file)

    generate_model_files(
        arm_length=config['arm_length'],
        num_motors=config['num_motors'],
        angle_offset=config['angle_offset'],
        model_name=config['model_name'],
        weight=config['weight'],
        Ixx=config['Ixx'],
        Iyy=config['Iyy'],
        Izz=config['Izz'],
        max_motor_thrust=config['max_motor_thrust'],
        first_motor_cw=config.get('first_motor_cw', True)
    )

def main(yaml_file: str) -> None:
    """
    Main function to load the YAML configuration and generate model files.

    :param yaml_file: Path to the YAML configuration file.
    :type yaml_file: str
    :return: None
    :rtype: None
    """
    load_config_and_generate_model(yaml_file)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <path_to_yaml_file>")
        sys.exit(1)

    yaml_file_path = sys.argv[1]
    main(yaml_file_path)
