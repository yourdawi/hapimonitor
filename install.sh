#!/bin/bash
set -e

GITHUB_REPO="https://github.com/yourdawi/hapimonitor"
VERSION="1.0.0"
CONFIG_FILE="/etc/hapimonitor/config.yaml"
SERVICE_FILE="/etc/systemd/system/hapimonitor.service"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Installation steps
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
ExecStart=/usr/bin/python3 /usr/local/bin/hapimonitor.py
Restart=always
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
  cat > /usr/local/bin/hapimonitor-cli <<EOL
#!/bin/bash
# CLI tool for HApiMonitor

function check_updates() {
  # Add update check logic
}

case "\$1" in
  "-up")
    echo "Checking for updates..."
    check_updates
    ;;
  *)
    echo "Usage: hapimonitor-cli [-up]"
    ;;
esac
EOL

  chmod +x /usr/local/bin/hapimonitor-cli
  ln -s /usr/local/bin/hapimonitor.py /usr/local/bin/hapimonitor
}

# Start installation
main_install
whiptail --title "Installation Complete" --msgbox "HApiMonitor successfully installed!" 8 40