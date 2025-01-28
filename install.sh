#!/bin/bash
set -e

GITHUB_REPO="https://github.com/yourdawi/hapimonitor"
VERSION="1.2.0"
CONFIG_FILE="/etc/hapimonitor/config.yaml"
SERVICE_FILE="/etc/systemd/system/hapimonitor.service"
INSTALL_DIR="/usr/local/bin"

# Uninstall function
function uninstall() {
    echo "Stopping service..."
    systemctl stop hapimonitor || true
    echo "Disabling service..."
    systemctl disable hapimonitor || true
    echo "Removing files..."
    rm -f $SERVICE_FILE
    rm -rf /etc/hapimonitor
    rm -f $INSTALL_DIR/hapimonitor
    rm -f $INSTALL_DIR/hapimonitor-cli
    rm -f $INSTALL_DIR/hapimonitor.py
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

# Main installation
function main_install() {
    apt-get update
    apt-get install -y python3 python3-pip python3-venv whiptail
    python3 -m pip install psutil paho-mqtt pyyaml

    mkdir -p /etc/hapimonitor
    config_mqtt
    create_service
    install_cli
}

function config_mqtt() {
    if [ -f "$CONFIG_FILE" ]; then
        if (whiptail --title "Existing Configuration" --yesno "Existing configuration found. Keep it?" 8 40); then
            return
        fi
    fi

    MQTT_BROKER=$(whiptail --inputbox "Enter MQTT Broker address:" 8 40 localhost --title "MQTT Configuration" 3>&1 1>&2 2>&3)
    MQTT_PORT=$(whiptail --inputbox "Enter MQTT Broker port:" 8 40 1883 --title "MQTT Configuration" 3>&1 1>&2 2>&3)
    MQTT_USER=$(whiptail --inputbox "Enter MQTT username:" 8 40 --title "MQTT Configuration" 3>&1 1>&2 2>&3)
    MQTT_PASS=$(whiptail --passwordbox "Enter MQTT password:" 8 40 --title "MQTT Configuration" 3>&1 1>&2 2>&3)

    cat > $CONFIG_FILE <<EOL
mqtt:
  broker: $MQTT_BROKER
  port: $MQTT_PORT
  username: $MQTT_USER
  password: $MQTT_PASS
update_interval: 60
EOL
}

function create_service() {
    if (whiptail --title "Service Setup" --yesno "Enable and start hapimonitor service?" 8 78); then
        cat > $SERVICE_FILE <<EOL
[Unit]
Description=HApiMonitor Service
After=network.target

[Service]
ExecStart=$INSTALL_DIR/hapimonitor.py
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOL

        systemctl daemon-reload
        systemctl enable hapimonitor
        systemctl start hapimonitor
    fi
}

function install_cli() {
    # Install main script
    cp hapimonitor.py $INSTALL_DIR/
    chmod +x $INSTALL_DIR/hapimonitor.py
    ln -sf $INSTALL_DIR/hapimonitor.py $INSTALL_DIR/hapimonitor

    # Install CLI tool
    cat > $INSTALL_DIR/hapimonitor-cli <<EOL
#!/bin/bash

function check_updates() {
    CURRENT_VERSION=\$(hapimonitor --version)
    LATEST_VERSION=\$(curl -s https://api.github.com/repos/yourdawi/hapimonitor/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    if [ "\$(printf '%s\n' "\$LATEST_VERSION" "\$CURRENT_VERSION" | sort -V | head -n1)" != "\$LATEST_VERSION" ]; then
        echo "New version available: \$LATEST_VERSION"
        if (whiptail --title "Update Available" --yesno "Update to \$LATEST_VERSION?" 8 40); then
            curl -sSL https://raw.githubusercontent.com/yourdawi/hapimonitor/main/install.sh | sudo bash
        fi
    else
        echo "Already up to date"
    fi
}

function uninstall() {
    if [ "\$EUID" -ne 0 ]; then
        echo "Please run with sudo"
        exit 1
    fi
    sudo bash $INSTALL_DIR/hapimonitor.py --uninstall
}

case "\$1" in
    "-up")
        check_updates
        ;;
    "-uninstall")
        uninstall
        ;;
    "--version")
        hapimonitor --version
        ;;
    *)
        echo "Usage: hapimonitor-cli [-up | -uninstall | --version]"
        ;;
esac
EOL

    chmod +x $INSTALL_DIR/hapimonitor-cli
}

# Start installation
main_install
whiptail --title "Installation Complete" --msgbox "HApiMonitor successfully installed!\n\nUse 'hapimonitor-cli -uninstall' to remove." 10 40