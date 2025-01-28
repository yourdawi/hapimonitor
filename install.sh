#!/bin/bash
set -e

GITHUB_REPO="https://github.com/yourdawi/hapimonitor"
VERSION="1.3.0"
CONFIG_FILE="/etc/hapimonitor/config.yaml"
SERVICE_FILE="/etc/systemd/system/hapimonitor.service"
INSTALL_DIR="/usr/local/bin"
BASE_URL="https://raw.githubusercontent.com/yourdawi/hapimonitor/main"

# Uninstall function
function uninstall() {
    echo "Stopping service..."
    systemctl stop hapimonitor || true
    echo "Disabling service..."
    systemctl disable hapimonitor || true
    echo "Removing files..."
    rm -f $SERVICE_FILE
    rm -rf /etc/hapimonitor
    rm -f $INSTALL_DIR/hapimonitor*
    systemctl daemon-reload
    echo "HApiMonitor successfully uninstalled!"
    exit 0
}

# Handle uninstall
if [ "$1" = "--uninstall" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Please run uninstall as root"
        exit 1
    fi
    uninstall
fi

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Download required files
function download_files() {
    echo "Downloading required files..."
    curl -sSL -o $INSTALL_DIR/hapimonitor.py $BASE_URL/hapimonitor.py
    curl -sSL -o $INSTALL_DIR/hapimonitor-cli $BASE_URL/hapimonitor-cli
    chmod +x $INSTALL_DIR/hapimonitor.py
    chmod +x $INSTALL_DIR/hapimonitor-cli
    ln -sf $INSTALL_DIR/hapimonitor.py $INSTALL_DIR/hapimonitor
}

# Main installation
function main_install() {
    apt-get update
    apt-get install -y python3 python3-pip python3-venv whiptail curl
    python3 -m pip install psutil paho-mqtt pyyaml

    mkdir -p /etc/hapimonitor
    download_files
    config_mqtt
    create_service
}

# Rest of the script remains the same as previous version...
# [Keep the config_mqtt, create_service functions unchanged from previous version]

# Start installation
main_install
whiptail --title "Installation Complete" --msgbox "HApiMonitor successfully installed!\n\nUse 'hapimonitor-cli -uninstall' to remove." 10 40