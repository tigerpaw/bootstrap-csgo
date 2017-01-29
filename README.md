# bootstrap-csgo
Bash script to bootstrap a csgo dedicated server on RHEL/CentOS 7

# Installation
`curl -s https://raw.githubusercontent.com/tigerpaw/bootstrap-csgo/master/boostrap-csgo.sh | bash -s install`

# Usage
Enable start on boot: `systemctl enable csgo`

Start: `systemctl start csgo`

Restart: `systemctl restart csgo`

Monitor Console: `journalctl --unit=csgo | tail -50`
