#!/usr/bin/env bash

# Default hub IP
DEFAULT_IP="192.168.0.105"

# If an argument is provided, use it; otherwise fall back to default
IP="${1:-$DEFAULT_IP}"

echo Connecting to $IP
# Run the SmartThings logcat command
smartthings edge:drivers:logcat --all --hub-address "$IP"
