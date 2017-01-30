# bootstrap-csgo
Bash script to bootstrap a Counter-Strike: Global Offensive dedicated server on RHEL/CentOS 7

## Installation
`curl -s https://raw.githubusercontent.com/tigerpaw/bootstrap-csgo/master/boostrap-csgo.sh | bash -s install <GSLT>`

## Usage
Install:  `bootstrap-csgo.sh install <GAME_SERVER_LICENSE_TOKEN>`

Repair Permissions: `bootstrap-csgo.sh repair`

(Experimental) Update Game Server Files: `bootstrap-csgo.sh update`

## Post-Installation
Enable start on boot: `systemctl enable csgo`

Start: `systemctl start csgo`

Restart: `systemctl restart csgo`

Check Console: `journalctl --unit=csgo | tail -50`

## License
This code is free software; you can redistribute it and/or modify it under the terms of the MIT License. A copy of this license can be found in the included LICENSE file.
