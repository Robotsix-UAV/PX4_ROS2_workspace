#!/usr/bin/env python3

"""
Copyright 2024 Damien Six (six.damien@robotsix.net)
SPDX-License-Identifier: Apache-2.0

Usage:
    python script_name.py --port /dev/ttyUSB0 --file params.txt
    or
    python script_name.py --file params.txt (auto-detect port)

Options:
    --port: The serial port to connect to the PX4 device.
    --file: The file containing parameters to set.
"""

import argparse
import struct
import sys
from typing import Optional
from pymavlink import mavutil

BAUD_RATES = [115200, 57600, 38400, 19200, 9600]


def detect_px4_connection(port: Optional[str] = None) -> mavutil.mavlink_connection:
    """
    Auto-detects the PX4 connection port if not provided and establishes a MAVLink connection.

    :param port: The serial port to connect to.
    :type port: str or None
    :return: A MAVLink connection object.
    :rtype: mavutil.mavlink_connection
    :raises Exception: If no serial connection is found or if connection fails.
    """
    if port is None:
        serial_list = mavutil.auto_detect_serial(
            preferred_list=[
                "*FTDI*",
                "*Arduino_Mega_2560*",
                "*3D_Robotics*",
                "*USB_to_UART*",
                "*PX4*",
                "*FMU*",
                "*Gumstix*",
            ]
        )

        if len(serial_list) == 0:
            raise ValueError("Error: no serial connection found")

        if len(serial_list) > 1:
            print("Auto-detected serial ports are:")
            for port_info in serial_list:
                print(f" {port_info}")
        port = serial_list[0].device
        print(f"Using port {port}")

    for baud in BAUD_RATES:
        try:
            connection = mavutil.mavlink_connection(port, baud=baud)
            send_heartbeat(connection)
            confirm_connection = connection.wait_heartbeat(timeout=5)
            if confirm_connection is None:
                raise ConnectionError("Failed to connect to PX4")
            print(f"Connected to PX4 on {port} with baud rate {baud}")
            return connection
        except Exception as e:
            print(f"Failed to connect on {port} with baud rate {baud}: {e}")

    raise ConnectionError(f"Failed to connect on {port} with any baud rate")


def set_parameters_from_file(connection: mavutil.mavlink_connection, filename: str) -> bool:
    """
    Sets parameters on the PX4 device from a specified file.

    :param connection: The MAVLink connection object.
    :type connection: mavutil.mavlink_connection
    :param filename: The file containing parameters to set.
    :type filename: str
    :return: True if all parameters are set successfully, False otherwise.
    :rtype: bool
    """
    with open(filename, "r", encoding="utf-8") as file:
        success = True
        for line in file:
            param, value_str = line.strip().split()
            if '.' in value_str:
                value = float(value_str)
                param_type = mavutil.mavlink.MAV_PARAM_TYPE_REAL32
                packed = struct.pack("f", value)
                value_f = struct.unpack("f", packed)[0]
            else:
                value = int(value_str)
                param_type = mavutil.mavlink.MAV_PARAM_TYPE_INT32
                packed = struct.pack("i", value)
                value_f = struct.unpack("f", packed)[0]

            print(f"Setting {param} to {value}")

            param_success = False
            retries = 0
            while not param_success and retries < 10:
                connection.param_set_send(
                    param, value_f, param_type
                )
                ack = connection.recv_match(
                    type="PARAM_VALUE", blocking=True, timeout=1)
                if ack:
                    ack = ack.to_dict()
                    if ack and ack["param_id"] == param and ack["param_value"] == value_f:
                        print(f"Successfully set {param} to {value}")
                        param_success = True
                    else:
                        print(f"Failed to set {param}")
                else:
                    print(f"No response from PX4 for {param}")
                retries += 1

            if not param_success:
                success = False

    return success


def do_reboot(connection: mavutil.mavlink_connection) -> None:
    """
    Sends a command to reboot the PX4 device.

    :param connection: The MAVLink connection object.
    :type connection: mavutil.mavlink_connection
    """
    print("Rebooting the PX4 device...")
    connection.reboot_autopilot()
    print("Reboot command sent.")


def send_heartbeat(connection: mavutil.mavlink_connection) -> None:
    """
    Sends a heartbeat message to the PX4 device at 1 Hz.

    :param connection: The MAVLink connection object.
    :type connection: mavutil.mavlink_connection
    """
    connection.mav.heartbeat_send(
        mavutil.mavlink.MAV_TYPE_GCS,
        mavutil.mavlink.MAV_AUTOPILOT_INVALID,
        0,
        0,
        0,
    )


def main() -> None:
    """
    Main function to parse arguments, establish connection, set parameters, and reboot the device.
    """
    parser = argparse.ArgumentParser(
        description="Set parameters on PX4 device")
    parser.add_argument("--port", help="Serial port to connect to PX4")
    parser.add_argument(
        "--file", default="params.txt", help="File containing parameters to set"
    )
    args = parser.parse_args()

    success = False
    try:
        connection = detect_px4_connection(args.port)
        success = set_parameters_from_file(connection, args.file)
        do_reboot(connection)
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        connection.close()
        if success:
            print("All parameters set successfully.")
            sys.exit(0)
        else:
            print("Failed to set all parameters.")
            sys.exit(1)


if __name__ == "__main__":
    main()
