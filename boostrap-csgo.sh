#!/bin/bash
yum install -y epel-release
yum update -y
yum upgrade -y
yum install -y git zsh vim htop curl wget gunzip screen tmux firewalld firewalld-filesystem glibc.i686 libstdc++.i686

useradd -d /home/steam -m -s /bin/zsh steam

mkdir /steam && cd $_
chmod -R steam:steam /steam

chsh -s /bin/zsh
systemctl enable firewalld.service
systemctl start firewalld.service
firewall-cmd --zone=public --add-port=27015/tcp --permanent
firewall-cmd --zone=public --add-port=27015/udp --permanent
firewall-cmd --reload

su - steam
cd /steam && curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
