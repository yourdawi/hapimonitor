#!/usr/bin/env python3
import time
import json
import socket
import psutil
import paho.mqtt.client as mqtt
import yaml
import os
from pathlib import Path

CONFIG_PATH = "/etc/hapimonitor/config.yaml"
VERSION = "1.0.0"

class HApiMonitor:
    def __init__(self):
        self.hostname = socket.gethostname()
        self.config = self.load_config()
        self.mqtt_client = self.setup_mqtt()
        self.discovery_sent = False

    def load_config(self):
        with open(CONFIG_PATH) as f:
            return yaml.safe_load(f)

    def setup_mqtt(self):
        client = mqtt.Client(client_id=f"hapimonitor_{self.hostname}")
        client.username_pw_set(self.config['mqtt']['username'], self.config['mqtt']['password'])
        client.connect(self.config['mqtt']['broker'], self.config['mqtt']['port'])
        client.loop_start()
        return client

    def publish_discovery(self):
        device = {
            "identifiers": [self.hostname],
            "name": self.hostname,
            "manufacturer": "Raspberry Pi",
            "model": "Raspberry Pi"
        }

        sensors = [
            ("cpu_usage", "CPU Usage", "%", "mdi:speedometer"),
            ("ram_usage", "RAM Usage", "%", "mdi:memory"),
            ("disk_usage", "Disk Usage", "%", "mdi:harddisk")
        ]

        for sensor_id, name, unit, icon in sensors:
            payload = {
                "name": f"{self.hostname} {name}",
                "state_topic": f"homeassistant/sensor/{self.hostname}/{sensor_id}/state",
                "unit_of_measurement": unit,
                "icon": icon,
                "unique_id": f"{self.hostname}_{sensor_id}",
                "device": device
            }
            
            self.mqtt_client.publish(
                f"homeassistant/sensor/{self.hostname}/{sensor_id}/config",
                json.dumps(payload),
                retain=True
            )

        self.discovery_sent = True

    def get_system_stats(self):
        return {
            "cpu_usage": psutil.cpu_percent(),
            "ram_usage": psutil.virtual_memory().percent,
            "disk_usage": psutil.disk_usage('/').percent
        }

    def run(self):
        while True:
            if not self.discovery_sent:
                self.publish_discovery()

            stats = self.get_system_stats()
            for sensor, value in stats.items():
                self.mqtt_client.publish(
                    f"homeassistant/sensor/{self.hostname}/{sensor}/state",
                    value
                )
            
            time.sleep(self.config['update_interval'])

if __name__ == "__main__":
    monitor = HAmonitor()
    monitor.run()