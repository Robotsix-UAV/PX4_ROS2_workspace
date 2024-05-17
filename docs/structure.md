# Repository Structure

The repository contains the following key directories and files:

- `docker/` - Directory containing Dockerfiles for building Docker images used in the project.
- `gz_sim/` - Directory containing Gazebo custom simulation files.
    - `custom_airframes/` - Directory containing custom airframe models for the Gazebo simulator with PX4 SITL.
    - `custom_worlds/` - Directory containing custom world models for the Gazebo simulator with PX4 SITL.
- `tests/` - Directory containing test scripts.
- `tools/` - Directory containing various utility scripts.
    - `configurations/` - Directory containing examples of configuration files for the scripts.
    - `docker_scripts/` - Directory containing scripts that run Docker containers.
    - `scripts/` - Directory containing shell and Python scripts called by the Docker scripts. These can be run outside of Docker as well with proper dependencies installed.
