#!/bin/bash
# curl -s https://raw.githubusercontent.com/tigerpaw/bootstrap-csgo/master/boostrap-csgo.sh | bash -s <GAME_SERVER_LICENSE_TOKEN>
# https://steamcommunity.com/dev/managegameservers

SERVICE_USR="steam"
INSTALL_DIR="/steam"
SRCDS_DIR="csgo_ds"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
GSLTOKEN="$1"

main() {
  printf "CS:GO Dedicated Server Bootstrapper (v0.2) for RHEL/CentOS 7.x\n===\n"

  CHK_RHEL=$(cat /etc/redhat-release | grep 7)
  if [ -z "$CHK_RHEL" ]; then console-write "This tool is requires RHEL/CentOS 7+"; fi

  CHK_EPEL=$(yum list installed | grep epel-release)
  if [ -z "$CHK_EPEL" ]; then console-write "Enabling EPEL repository" && yum install -y epel-release; fi

  console-write "Updating System"
  yum update -y && yum upgrade -y

  console-write "Checking packages"
  CHK_PKGS=(
    "sudo"
    "git.x86_64"
    "zsh"
    "vim-enhanced"
    "htop"
    "curl"
    "wget"
    "screen"
    "tmux"
    "firewalld"
    "firewalld-filesystem"
  )
  PKGS=()
  for i in "${CHK_PKGS[@]}"
  do
    CHK_PKG=$(yum list installed | grep $i)
    if [ -z "$CHK_PKG" ]; then
      console-write "Marking $i for installation"
      PKGS+=("$i")
    else
      console-write "$i is installed"
    fi
  done

  if [ $(uname -m) == "x86_64" ]; then
    console-write "64-bit archictecture detected, forcing 32-bit C/C++ libraries"
    PKGS+=("glibc.i686" "libstdc++.i686")
  else
    console-write "32-bit architecture detected, using standard C/C++ libraries"
    PKGS+=("glibc" "libstdc++")
  fi

  if [ -n "$PKGS" ]; then yum install -y ${PKGS[@]}; fi

  if [ $(grep -c '^steam:' /etc/passwd) == 0 ]; then
    console-write "Checking service account"
    useradd -d /home/steam -m -s /bin/zsh steam
  fi

  if [ ! -d "/steam" ]; then
    console-write "Prepping filesystem"
    mkdir /steam
    if [ ! -d "/steam/steamcmd" ]; then mkdir /steam/steamcmd; fi
  fi

  CHK_FIREWALL=$(yum list installed | grep firewalld)
  if [ -n "$CHK_FIREWALL" ]; then
    console-write "Enabling and configuring firewalld"
    systemctl enable firewalld.service
    systemctl start firewalld.service
    console-write "Adding firewall rule for 27015/tcp"
    firewall-cmd --zone=public --add-port=27015/tcp --permanent
    console-write "Adding firewall rule for 27015/udp"
    firewall-cmd --zone=public --add-port=27015/udp --permanent
    console-write "Reloading firewall"
    firewall-cmd --reload
  fi

  if [ ! -f "/steam/steamcmd/steamcmd.sh" ]; then
    console-write "Installing SteamCMD"
    sudo -u steam curl -sqL "$STEAMCMD_URL" | tar zxvf - -C /steam/steamcmd
  fi

  if [ ! -d "/steam/csgo_ds" ]; then
    console-write "Installing CS:GO Dedicated Server"
    ( sudo -u steam cd /steam && exec "/steam/steamcmd/steamcmd.sh" "+login anonymous" "+force_install_dir /steam/csgo_ds" "+app_update 740" "+quit" )
  fi

  if [ ! -f "/steam/csgo_ds/csgo/cfg/autoexec.cfg" ]; then
    console-write "Creating autoexec.cfg"
    echo "sv_setsteamaccount \"$GSLTOKEN\"" >> /steam/csgo_ds/csgo/cfg/autoexec.cfg
    echo "log on" >> /steam/csgo_ds/csgo/cfg/autoexec.cfg
    echo "rcon_password \"$(date +%s)\"" >> /steam/csgo_ds/csgo/cfg/autoexec.cfg
    echo "sv_cheats \"\"" >> /steam/csgo_ds/csgo/cfg/autoexec.cfg
    echo "sv_cheats 0" >> /steam/csgo_ds/csgo/cfg/autoexec.cfg
    echo "sv_lan 0" >> /steam/csgo_ds/csgo/cfg/autoexec.cfg
    echo "exec banned_user.cfg" >> /steam/csgo_ds/csgo/cfg/autoexec.cfg
    echo "exec banned_ip.cfg" >> /steam/csgo_ds/csgo/cfg/autoexec.cfg
  fi

  if [ ! -f "/steam/csgo_ds/csgo/cfg/server.cfg" ]; then
    console-write "Creating server.cfg"
    echo "mp_autoteambalance 1" >> /steam/csgo_ds/csgo/cfg/server.cfg
    echo "mp_limitteams 1" >> /steam/csgo_ds/csgo/cfg/server.cfg
    echo "writeid" >> /steam/csgo_ds/csgo/cfg/server.cfg
    echo "writeip" >> /steam/csgo_ds/csgo/cfg/server.cfg
  fi

  if [ ! -f "/steam/csgo_ds/.csgo-service-conf" ]; then
    echo "AUTOUPDATE=\"-autoupdate\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "GAME=\"-game csgo\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "CONSOLE=\"-console\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "USERCON=\"-usercon\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "TOKEN=\"+sv_setsteamaccount $GSLTOKEN\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "NETPORTRY=\"-net_port_try 1\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "GAMETYPE=\"+game_type 0\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "GAMEMODE=\"+game_mode 1\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "MAPGROUP=\"+mapgroup mg_active\"" >> /steam/csgo_ds/.csgo-service-conf
    echo "MAP=\"+map de_mirage\"" >> /steam/csgo_ds/.csgo-service-conf
  fi

  if [ ! -f "/etc/systemd/system/csgo.service" ]; then
    console-write "Installing csgo.service"
    echo "[Unit]" >> /etc/systemd/system/csgo.service
    echo "Description=CS:GO Dedicated Server" >> /etc/systemd/system/csgo.service
    echo "After=network.target" >> /etc/systemd/system/csgo.service
    echo -e "\n[Service]" >> /etc/systemd/system/csgo.service
    echo "Type=simple" >> /etc/systemd/system/csgo.service
    echo "User=$SERVICE_USR" >> /etc/systemd/system/csgo.service
    echo "WorkingDirectory=/steam/csgo_ds" >> /etc/systemd/system/csgo.service
    echo "Environment=\"LD_LIBRARY_PATH=/steam/csgo_ds:/steam/csgo_ds/bin\"" >> /etc/systemd/system/csgo.service
    echo "EnvironmentFile=/steam/csgo_ds/.csgo-service-conf" >> /etc/systemd/system/csgo.service
    echo "ExecStart=/steam/csgo_ds/srcds_run \${AUTOUPDATE} \${GAME} \${CONSOLE} \${USERCON} \${TOKEN} \${NETPORTTRY} \${GAMETYPE} \${GAMEMODE} \${MAPGROUP} \${MAP}" >> /etc/systemd/system/csgo.service
    echo "Restart=always" >> /etc/systemd/system/csgo.service
    console-write "Reloading systemd"
    systemctl daemon-reload
    console-write "Start: systemctl enable csgo && systemctl start csgo"
  fi

  chown -R steam:steam /steam
  console-write "Complete!"
}

console-write() {
  printf "[Bootstrapper] : $1\n"
}

main "$@"
