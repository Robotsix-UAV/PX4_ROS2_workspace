# Drone Log Collection Script

This script is designed to collect log files from multiple drones specified as a comma-separated list. It connects to each drone via SSH, retrieves the UAV name, creates a local directory, and synchronizes the logs from the remote drone to the local directory.

## Prerequisites

Before using this script, ensure that:

1. You have SSH access to all the drones.
2. You have generated SSH keys for passwordless authentication.
3. You must have run the `install_offboard.sh` script on each drone to set up the environment variables and log directories.

### Generate SSH Key (if not done already)

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

### Copy the SSH Key to Each Drone

To enable passwordless SSH connections to each drone, use the following command:

```bash
ssh-copy-id user@ip_address
```

Replace `user@ip_address` with the appropriate username and IP address for each drone.

## Usage

### Collecting Logs from a Single Drone

To collect logs from a single drone, use the following command:

```bash
./collect_logs.sh user1@192.168.1.101
```

Replace `user1@192.168.1.101` with the appropriate `user@ip` format for your drone.

### Collecting Logs from Multiple Drones

To collect logs from multiple drones, you can specify a comma-separated list of drones in the format `user@ip`:

```bash
./collect_logs.sh user1@192.168.1.101,user2@192.168.1.102
```

### Using an Environment Variable for Drone List

Optionally, you can define the drone list as an environment variable, which can be added to your `.bashrc` for convenience.

1. Export the drone list:

    ```bash
    export DRONES="user1@192.168.1.101,user2@192.168.1.102,user3@192.168.1.103"
    ```

2. Run the script using the environment variable:

    ```bash
    ./collect_logs.sh $DRONES
    ```

To make the environment variable persistent, you can add the `export DRONES` line to your `.bashrc` file.

### Examples

- **Single Drone:**

    ```bash
    ./collect_logs.sh user1@192.168.1.101
    ```

- **Multiple Drones:**

    ```bash
    ./collect_logs.sh user1@192.168.1.101,user2@192.168.1.102
    ```

- **Using Environment Variable:**

    ```bash
    export DRONES="user1@192.168.1.101,user2@192.168.1.102,user3@192.168.1.103"
    ./collect_logs.sh $DRONES
    ```

## Script Description

The `collect_logs.sh` script performs the following steps:

1. **SSH Connection**: Connects to each drone via SSH using the provided `user@ip` details.
2. **UAV Name Retrieval**: Retrieves the `UAV_NAME` environment variable from the drone.
3. **Local Directory Creation**: Creates a local directory based on the retrieved `UAV_NAME` to store the logs.
4. **Log Synchronization**: Uses `rsync` to copy the logs from the drone to the local directory.

