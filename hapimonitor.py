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
VERSION = "1.2.0"

class HApiMonitor:
    def __init__(self):
        self.hostname = socket.gethostname()
        self.config = self.load_config()
        self.mqtt_client = self.setup_mqtt()
        self.discovery_sent = False

    def load_config(self):
        with open(CONFIG_PATH) as f:
            return yaml.safe_load(f)

    def get_device_info(self):
        try:
            with open('/proc/device-tree/model', 'r') as f:
                model = f.read().strip('\x00').replace('Raspberry Pi ', '')
                manufacturer = "Raspberry Pi Foundation"
        except:
            model = "Unknown Device"
            manufacturer = "Unknown Manufacturer"
        
        return {
            "identifiers": [self.hostname],
            "name": self.hostname,
            "manufacturer": manufacturer,
            "model": model,
            "sw_version": VERSION
        }

    def setup_mqtt(self):
        client = mqtt.Client(client_id=f"hapimonitor_{self.hostname}")
        client.username_pw_set(self.config['mqtt']['username'], self.config['mqtt']['password'])
        
        client.will_set(
            f"homeassistant/sensor/{self.hostname}/status",
            "offline",
            retain=True
        )
        
        try:
            client.connect(self.config['mqtt']['broker'], self.config['mqtt']['port'], 60)
            client.publish(f"homeassistant/sensor/{self.hostname}/status", "online", retain=True)
        except Exception as e:
            print(f"MQTT connection error: {str(e)}")
            exit(1)
            
        client.loop_start()
        return client

    def publish_discovery(self):
        device = self.get_device_info()

        sensors = [
            ("cpu_usage", "CPU Usage", "%", "mdi:speedometer"),
            ("ram_usage", "RAM Usage", "%", "mdi:memory"),
            ("disk_usage", "Disk Usage", "%", "mdi:harddisk"),
            ("status", "Status", "", "mdi:heart-pulse")
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
            "disk_usage": psutil.disk_usage('/').percent,
            "status": "online"
        }

    def run(self):
        discovery_interval = 3600
        last_discovery = 0
        
        while True:
            now = time.time()
            if not self.discovery_sent or (now - last_discovery) > discovery_interval:
                self.publish_discovery()
                last_discovery = now
                self.discovery_sent = True

            stats = self.get_system_stats()
            for sensor, value in stats.items():
                self.mqtt_client.publish(
                    f"homeassistant/sensor/{self.hostname}/{sensor}/state",
                    value,
                    retain=True
                )
            
            time.sleep(self.config['update_interval'])

if __name__ == "__main__":
    monitor = HApiMonitor()
    monitor.run()