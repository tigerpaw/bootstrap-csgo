#!/bin/bash
# bootstrap-csgo.sh
# Version 0.3
# -
# curl -s https://raw.githubusercontent.com/tigerpaw/bootstrap-csgo/master/boostrap-csgo.sh | bash -s (install | update | repair)
# Get a Game Server License Token: https://steamcommunity.com/dev/managegameservers

SERVICE_USR="steam"
INSTALL_DIR="/steam"
SRCDS_DIR="$INSTALL_DIR/csgo_ds"
CSGO_DIR="$SRCDS_DIR/csgo"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

main() {
  printf "CS:GO Dedicated Server Bootstrapper (v0.3) for RHEL/CentOS 7.x\n===\n"

  # Check if RHEL/CentOS 7.x
  CHK_RHEL=$(cat /etc/redhat-release | grep 7)
  if [ -z "$CHK_RHEL" ]; then bootout "This tool is requires RHEL/CentOS 7.x\n" && exit 1; fi

  if [ $1 == "install" ]; then
    # Get GSLT
    read -p "Game Server License Token (GSLT): " GSLTOKEN
    exit
    # Enable EPEL if it isn't enabled
    bootout "Enabling EPEL repository\n"
    CHK_EPEL=$(yum list installed | grep epel-release)
    if [ -z "$CHK_EPEL" ]; then yum install -y epel-release; fi

    # Update binaries
    bootout "Running Sytem Update\n"
    yum update -y && yum upgrade -y

    bootout "Checking packages\n"
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
    # Check arch to determine C/C++ lib package, srcds always requires 32-bit
    if [ $(uname -m) == "x86_64" ]; then
      bootout "64-bit archictecture detected, forcing 32-bit C/C++ libraries\n"
      PKGS+=("glibc.i686" "libstdc++.i686")
    else
      bootout "32-bit architecture detected, using standard C/C++ libraries\n"
      PKGS+=("glibc" "libstdc++")
    fi
    # Check if any of these packages are already installed
    PKGS=()
    for i in "${CHK_PKGS[@]}"
    do
      CHK_PKG=$(yum list installed | grep $i)
      if [ -z "$CHK_PKG" ]; then
        bootout "Marking $i for installation\n"
        PKGS+=("$i")
      else
        bootout "Skipping $i\n"
      fi
    done

    # Install packages
    if [ -n "$PKGS" ]; then yum install -y ${PKGS[@]}; fi

    # Create service account if it doesn't exist
    if id "$SERVICE_USR" >/dev/null 2>&1; then
      bootout "Checking service account\n"
      useradd -d /home/$SERVICE_USR -m -s /bin/zsh $SERVICE_USR
    fi

    CHK_FIREWALL=$(yum list installed | grep firewalld)
    if [ -n "$CHK_FIREWALL" ]; then
      bootout "Enabling and configuring firewalld\n"
      systemctl enable firewalld.service
      systemctl start firewalld.service
      bootout "Adding firewall rule for 27015/tcp: "
      firewall-cmd --zone=public --add-port=27015/tcp --permanent
      bootout "Adding firewall rule for 27015/udp: "
      firewall-cmd --zone=public --add-port=27015/udp --permanent
      bootout "Reloading firewall: "
      firewall-cmd --reload
    fi

    # Install SteamCMD
    if [ ! -f "$INSTALL_DIR/steamcmd/steamcmd.sh" ]; then
      bootout "Installing SteamCMD\n"
      if [ ! -d "$INSTALL_DIR" ]; then
        bootout "Prepping filesystem\n"
        mkdir $INSTALL_DIR
        if [ ! -d "$INSTALL_DIR/steamcmd" ]; then mkdir $INSTALL_DIR/steamcmd; fi
      fi
      sudo -u $SERVICE_USR curl -sqL "$STEAMCMD_URL" | tar zxvf - -C $INSTALL_DIR/steamcmd
    fi

    # Install CS:GO
    if [ ! -d "$SRCDS_DIR" ]; then
      bootout "Installing CS:GO Dedicated Server\n"
      ( exec "$INSTALL_DIR/steamcmd/steamcmd.sh" "+login anonymous" "+force_install_dir $SRCDS_DIR" "+app_update 740 validate" "+quit" )
    fi

    # Build default configs if they don't exist
    F_AUTOEXEC="$CSGO_DIR/cfg/autoexec.cfg"
    if [ ! -f "$F_AUTOEXEC" ]; then
      bootout "Creating autoexec.cfg\n"
      echo "sv_setsteamaccount \"$GSLTOKEN\"" >> $F_AUTOEXEC
      echo "log on" >> $F_AUTOEXEC
      echo "rcon_password \"$(date +%s)\"" >> $F_AUTOEXEC
      echo "sv_cheats \"\"" >> $F_AUTOEXEC
      echo "sv_cheats 0" >> $F_AUTOEXEC
      echo "sv_lan 0" >> $F_AUTOEXEC
      echo "exec banned_user.cfg" >> $F_AUTOEXEC
      echo "exec banned_ip.cfg" >> $F_AUTOEXEC
    fi

    F_SERVER="$CSGO_DIR/cfg/server.cfg"
    if [ ! -f "$F_SERVER" ]; then
      bootout "Creating server.cfg\n"
      echo "mp_autoteambalance 1" >> $F_SERVER
      echo "mp_limitteams 1" >> $F_SERVER
      echo "writeid" >> $F_SERVER
      echo "writeip" >> $F_SERVER
    fi

    # Build environment config file for systemd service
    F_SERVICECONF="$SRCDS_DIR/.csgo-service-conf"
    if [ ! -f "$F_SERVICECONF" ]; then
      echo "AUTOUPDATE=\"-autoupdate\"" >> $F_SERVICECONF
      echo "TICKRATE=\"-tickrate 128\"" >> $F_SERVICECONF
      echo "GAME=\"-game csgo\"" >> $F_SERVICECONF
      echo "GAME=\"-tickrate 128\"" >> $F_SERVICECONF
      echo "CONSOLE=\"-console\"" >> $F_SERVICECONF
      echo "USERCON=\"-usercon\"" >> $F_SERVICECONF
      echo "TOKEN=\"+sv_setsteamaccount $GSLTOKEN\"" >> $F_SERVICECONF
      echo "NETPORTRY=\"-net_port_try 1\"" >> $F_SERVICECONF
      echo "GAMETYPE=\"+game_type 0\"" >> $F_SERVICECONF
      echo "GAMEMODE=\"+game_mode 1\"" >> $F_SERVICECONF
      echo "MAPGROUP=\"+mapgroup mg_active\"" >> $F_SERVICECONF
      echo "MAP=\"+map de_mirage\"" >> $F_SERVICECONF
    fi

    # Build systemd service
    F_SERVICE="/etc/systemd/system/csgo.service"
    if [ ! -f "$F_SERVICE" ]; then
      bootout "Installing csgo.service\n"
      echo "[Unit]" >> $F_SERVICE
      echo "Description=CS:GO Dedicated Server" >> $F_SERVICE
      echo "After=network.target" >> $F_SERVICE
      echo -e "\n[Service]" >> $F_SERVICE
      echo "Type=simple" >> $F_SERVICE
      echo "User=$SERVICE_USR" >> $F_SERVICE
      echo "WorkingDirectory=/steam/csgo_ds" >> $F_SERVICE
      echo "Environment=\"LD_LIBRARY_PATH=$SRCDS_DIR:$SRCDS_DIR/bin\"" >> $F_SERVICE
      echo "EnvironmentFile=$SRCDS_DIR/.csgo-service-conf" >> $F_SERVICE
      echo "ExecStart=$SRCDS_DIR/srcds_run \${AUTOUPDATE} \${GAME} \${TICKRATE} \${CONSOLE} \${USERCON} \${TOKEN} \${NETPORTTRY} \${GAMETYPE} \${GAMEMODE} \${MAPGROUP} \${MAP}" >> $F_SERVICE
      echo "Restart=always" >> $F_SERVICE
      bootout "Reloading systemd\n"
      systemctl daemon-reload
      bootout "Start: systemctl enable csgo && systemctl start csgo\n"
    fi
  fi

  if [ $1 == "update" ]; then
    bootout "Nothing here yet\n"
  fi

  # Fix permissions
  if [[ $1 == "repair" ]] || [[ $1 == "install" ]]; then
    bootout "Changing ownership of $INSTALL_DIR to $SERVICE_USR\n"
    chown -R $SERVICE_USER:$SERVICE_USER $INSTALL_DIR
  fi

  bootout "Complete!\n"
}

bootout() {
  printf "[Bootstrapper] : $1"
}

main "$@"
