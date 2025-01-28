#!/bin/bash
set -e

GITHUB_REPO="https://github.com/yourdawi/hapimonitor"
VERSION="0.0.2"
CONFIG_FILE="/etc/hapimonitor/config.yaml"
SERVICE_FILE="/etc/systemd/system/hapimonitor.service"
INSTALL_DIR="/usr/local/bin"
BASE_URL="https://raw.githubusercontent.com/yourdawi/hapimonitor/main"


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

function config_mqtt() {
    if [ -f "$CONFIG_FILE" ]; then
        dialog --ascii-lines --stdout --title "Existing Configuration" --yesno "Existing configuration found. Keep it?" 8 40
        response=$?
        if [ $response -eq 0 ]; then
            return
        fi
    fi

    MQTT_BROKER=$(dialog --ascii-lines --stdout --inputbox "Enter MQTT Broker address:" 8 40 "localhost")
    MQTT_PORT=$(dialog --ascii-lines --stdout --inputbox "Enter MQTT Broker port:" 8 40 "1883")
    MQTT_USER=$(dialog --ascii-lines --stdout --inputbox "Enter MQTT username:" 8 40 "")
    MQTT_PASS=$(dialog --ascii-lines --stdout --passwordbox "Enter MQTT password:" 8 40 "")

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
    if (dialog --stdout --title "Service Setup" --yesno "Enable and start hapimonitor service?" 8 78); then
        cat > $SERVICE_FILE <<EOL
[Unit]
Description=HApiMonitor Service
After=network.target

[Service]
ExecStart=/bin/bash -c 'source /etc/hapimonitor/venv/bin/activate && exec python3 $INSTALL_DIR/hapimonitor.py'
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

function download_files() {
    echo "Downloading required files..."
    curl -sSL -o $INSTALL_DIR/hapimonitor.py $BASE_URL/hapimonitor.py
    curl -sSL -o $INSTALL_DIR/hapimonitor-cli $BASE_URL/hapimonitor-cli
    chmod +x $INSTALL_DIR/hapimonitor.py
    chmod +x $INSTALL_DIR/hapimonitor-cli
    ln -sf $INSTALL_DIR/hapimonitor.py $INSTALL_DIR/hapimonitor
}

function main_install() {
    apt-get update
    apt-get install -y python3 python3-pip python3-venv dialog curl
    python3 -m venv /etc/hapimonitor/venv
    source /etc/hapimonitor/venv/bin/activate
    /etc/hapimonitor/venv/bin/pip install psutil paho-mqtt pyyaml

    mkdir -p /etc/hapimonitor
    download_files
    config_mqtt
    create_service
}

if [ "$1" = "--uninstall" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Please run uninstall as root"
        exit 1
    fi
    uninstall
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

main_install
dialog --ascii-lines --stdout --title "Installation Complete" --msgbox "HApiMonitor successfully installed!\n\nUse 'hapimonitor-cli -uninstall' to remove." 10 40