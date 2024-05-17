# Custom models

This folder contains custom airframe models for the Gazebo simulator with PX4 SITL. You can add custom airframe models to this directory and use them in the simulation configuration file.

## Directory Structure

The directory should contain one subdirectory for each custom airframe model. Assuming the custom airframe model is named `my_custom_model`, the directory structure should look like this:

- `my_custom_model/`
    - `meshes/` - Directory containing the mesh files for the custom airframe model.
    - `model.config` - Configuration file for the custom airframe model.
    - `model.sdf` - SDF file for the custom airframe model.
    - `my_custom_model` - Configuration file for PX4 startup.