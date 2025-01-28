
# HAPi Monitor

Running multiple RPis? Want to check their System in Home Assistant?

With the System Monitor Integration you can easy do this for the RPi you run HomeAssistant on.
But if you have some more? Like a MagicMirror? I created a MQTT way to get this informations.




## Features

- One Step automated install
- Get the stats of your Raspberry Pis in Home Assistant
- Update function
- Easy uninstall
- Service option to stay always active

## FAQ

#### How can i install this?

I created a easy way to install this.
Just run
```
curl -sSL https://raw.githubusercontent.com/yourdawi/hapimonitor/main/install.sh | sudo bash
```
The installer will ask for any informations, like your MQTT Broker IP, Port, Username, Password
#### hapimonitor-cli?

With the hapimonitor-cli command you can run commands.
```
hapimonitor-cli -h
```
It will display all avaible commands

#### Commands?
| Command            | Description                                                                  |
|---------------------|------------------------------------------------------------------------------|
| -up            | Updating HAPi Monitor                                    |
| -uninstall           | Remove HAPi Monitor from your system                         |



