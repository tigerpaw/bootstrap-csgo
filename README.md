# bootstrap-csgo
Bash script to bootstrap a Counter-Strike: Global Offensive dedicated server on RHEL/CentOS 7

# Installation
`curl -s https://raw.githubusercontent.com/tigerpaw/bootstrap-csgo/master/boostrap-csgo.sh | bash -s install <GSLT>`

# Usage
Enable start on boot: `systemctl enable csgo`

Start: `systemctl start csgo`

Restart: `systemctl restart csgo`

Check Console: `journalctl --unit=csgo | tail -50`

## License
This code is free software; you can redistribute it and/or modify it under the terms of the MIT License. A copy of this license can be found in the included LICENSE file.
