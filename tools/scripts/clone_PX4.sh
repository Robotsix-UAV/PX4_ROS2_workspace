#!/bin/bash

# ==============================================================================
# Copyright 2024 Damien Six (six.damien@robotsix.net)
#
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# PX4-Autopilot Cloning Script
#
# This script automates the process of cloning the PX4-Autopilot repository and
# checking out the desired git branch or tag. It prompts for necessary inputs
# if not specified through options.
#
# Usage:
#   ./clone_PX4.sh [options]
#
# Options:
#   -h      Show this help message and exit
#   -b      Specify the git branch.
#   -t      Specify the git tag (latest or custom). If 'latest' is specified, the latest release tag will be checked out.
#   -a      Automatically clone PX4-Autopilot if not found
#
# Example:
#   ./clone_PX4.sh -b main -a
#   ./clone_PX4.sh -t latest -a
# ==============================================================================

# ------------------------------------------------------------------------------
# Function to display the help message
# ------------------------------------------------------------------------------
show_help() {
    echo -e "Usage: $0 [-h] [-b branch] [-t tag] [-a]"
    echo -e "  -h   Display this help message."
    echo -e "  -b   Specify the git branch."
    echo -e "  -t   Specify the git tag (latest or custom). If 'latest' is specified, the latest release tag will be checked out."
    echo -e "  -a   Automatically clone PX4-Autopilot if not found."
    echo -e "If no options are given, the script will prompt for necessary inputs."
}

# ------------------------------------------------------------------------------
# Define ANSI color codes for output formatting
# ------------------------------------------------------------------------------
RED='\033[0;31m'
NC='\033[0m' # No Color

auto_clone=false
skip_checkout=false
branch=""
tag=""

# ------------------------------------------------------------------------------
# Ensure required commands are available
# ------------------------------------------------------------------------------
command -v git >/dev/null 2>&1 || {
    echo -e "${RED}git is not installed. Aborting.${NC}"
    exit 1
}

command -v docker >/dev/null 2>&1 || {
    echo -e "${RED}docker is not installed. Aborting.${NC}"
    exit 1
}

# ------------------------------------------------------------------------------
# Parse command-line options
# ------------------------------------------------------------------------------
while getopts "hb:t:a" opt; do
    case ${opt} in
    h)
        show_help
        exit 0
        ;;
    b)
        branch=${OPTARG}
        ;;
    t)
        tag=${OPTARG}
        ;;
    a)
        auto_clone=true
        ;;
    \?)
        echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
        exit 1
        ;;
    esac
done

# ------------------------------------------------------------------------------
# Check if both branch and tag are defined
# ------------------------------------------------------------------------------
if [ -n "${branch}" ] && [ -n "${tag}" ]; then
    echo -e "${RED}Error: Both branch and tag cannot be specified simultaneously.${NC}" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Function that returns the latest release tag from the PX4-Autopilot repository
# ------------------------------------------------------------------------------
get_latest_release() {
    # GitHub API URL for releases
    RELEASES_URL="https://api.github.com/repos/PX4/PX4-Autopilot/releases"

    # Fetch releases data from GitHub API
    releases_json=$(curl -s -L \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        $RELEASES_URL)

    # Parse the JSON data to find the first non-prerelease tag
    docker pull imega/jq
    latest_tag=$(echo $releases_json | docker run --rm -i imega/jq '[.[] | select(.prerelease == false)] | .[0].tag_name')
    # Remove quotes from the tag
    latest_tag=$(echo $latest_tag | tr -d '"')

    # Check if a valid tag was found and output the result
    if [ -n "$latest_tag" ]; then
        echo "Latest tag found $latest_tag"
    else
        echo -e "${RED}Failed to fetch latest release tag.${NC}"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Function to handle user input for branch or tag selection
# ------------------------------------------------------------------------------
select_checkout() {
    if [ -n "${tag}" ]; then
        if [ "${tag}" = "latest" ]; then
            get_latest_release
            tag=$latest_tag
        fi
    elif [ -z "${branch}" ]; then
        current_branch=$(git branch --show-current)
        echo -e "Select the branch or tag you wish to checkout:"
        echo -e "1) Latest release tag"
        echo -e "2) Main branch"
        echo -e "3) Custom tag"
        echo -e "4) Custom branch"
        echo -e "5) Skip checkout"
        echo -e -n "${RED}Enter choice (1-5): ${NC}"
        read choice

        case $choice in
        1)
            get_latest_release
            tag=$latest_tag
            ;;
        2)
            branch="main"
            ;;
        3)
            echo -e -n "${RED}Enter the tag: ${NC}"
            read tag
            ;;
        4)
            echo -e -n "${RED}Enter the branch: ${NC}"
            read branch
            ;;
        5)
            skip_checkout=true
            ;;
        *)
            echo -e "${RED}Invalid selection.${NC}"
            exit 1
            ;;
        esac
        select_checkout
    fi
}

# ------------------------------------------------------------------------------
# Check for PX4-Autopilot directory and clone if necessary
# ------------------------------------------------------------------------------
SCRIPT_DIR=$(readlink -f $(dirname "$0"))
cd "$SCRIPT_DIR/../.."
if [ ! -d "PX4-Autopilot" ]; then
    if [ "$auto_clone" = true ]; then
        echo -e "${RED}PX4-Autopilot directory not found. Cloning automatically.${NC}"
        git clone https://github.com/PX4/PX4-Autopilot.git || {
            echo -e "${RED}Failed to clone PX4-Autopilot. Aborting.${NC}"
            exit 1
        }
    else
        echo -e "${RED}PX4-Autopilot directory not found. Clone it? (y/n)${NC}"
        read answer
        if [[ $answer =~ ^[Yy]$ ]]; then
            git clone https://github.com/PX4/PX4-Autopilot.git || {
                echo -e "${RED}Failed to clone PX4-Autopilot. Aborting.${NC}"
                exit 1
            }
        else
            echo -e "${RED}PX4-Autopilot directory is required. Aborting.${NC}"
            exit 1
        fi
    fi
fi

cd PX4-Autopilot

# ------------------------------------------------------------------------------
# Checkout the branch or tag
# ------------------------------------------------------------------------------
select_checkout

if [ -n "${branch}" ]; then
    git checkout $branch -f && git pull && git submodule update --init --recursive || {
        echo -e "${RED}Failed to checkout branch $branch. Aborting.${NC}"
        exit 1
    }
fi

if [ -n "${tag}" ]; then
    git checkout $tag -f && git submodule update --init --recursive || {
        echo -e "${RED}Failed to checkout tag $tag. Aborting.${NC}"
        exit 1
    }
fi
