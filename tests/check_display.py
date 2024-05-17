#!/usr/bin/env python3

"""
Copyright 2024 Damien Six (six.damien@robotsix.net)
SPDX-License-Identifier: Apache-2.0

Script to check if a display is connected to the system.

Usage:
    python script.py

Steps Performed:
1. Run the xrandr command to check connected displays.
2. Parse the output to see if there are any monitors listed.
3. Print the result to the console.
"""

import subprocess
import sys


def check_display():
    """
    Check if a display is connected to the system.

    :return: True if a display is connected, False otherwise.
    :rtype: bool
    """

    try:
        # Run the xrandr command to check connected displays
        result = subprocess.run(
            ['xrandr', '--listmonitors'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)

        # Decode the output
        output = result.stdout.decode('utf-8')
        error = result.stderr.decode('utf-8')

        if result.returncode != 0:
            print(f"Error checking displays: {error}")
            return False

        # Parse the output to see if there are any monitors listed
        if "Monitors: 0" in output:
            print("No displays connected.")
            return False
        else:
            print("At least one display is connected.")
            return True

    except Exception as e:
        print(f"An error occurred: {e}")
        return False


if __name__ == "__main__":
    if check_display():
        print("Display check passed.")
        sys.exit(0)
    else:
        print("Display check failed.")
        sys.exit(1)
