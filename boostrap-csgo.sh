#!/bin/bash
# bootstrap-csgo.sh
# Version 0.4.3
# -
# curl -s https://raw.githubusercontent.com/tigerpaw/bootstrap-csgo/master/boostrap-csgo.sh | bash -s (install <GAME_SERVER_LICENSE_TOKEN> | update | repair)
# Get a Game Server License Token: https://steamcommunity.com/dev/managegameservers
# SteamCMD: https://developer.valvesoftware.com/wiki/SteamCMD
# CS:GO Dedicated Servers: https://developer.valvesoftware.com/wiki/Counter-Strike:_Global_Offensive_Dedicated_Servers

SERVICE_USR="steam"
INSTALL_DIR="/steam"
SRCDS_DIR="$INSTALL_DIR/csgo_ds"
CSGO_DIR="$SRCDS_DIR/csgo"
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
GSLTOKEN="$2"

function main() {
  printf "CS:GO Dedicated Server Bootstrapper (v0.4.3) for RHEL/CentOS 7.x\n===\n"

  # Check if RHEL/CentOS 7.x
  CHK_RHEL=$(cat /etc/redhat-release | grep 7)
  if [ -z "$CHK_RHEL" ]; then console_out "This tool requires RHEL/CentOS 7.x\n" && exit 1; fi

  # Validate input
  case "$1" in
    install)
      if [ -z $2 ]; then
        console_out "No game server license token provided\n"
        console_out "Example: bootstrap-csgo.sh install 93ECDE6B7526D1CAA699DA32D7E7DBB0\n"
        console_out "Get a GSLT: https://steamcommunity.com/dev/managegameservers\n\n"
        exit 1
      fi
      ;;

    update)
      console_out "WARNING - Experimental feature, use at your own risk. Good luck!\n"
      continue
      ;;

    repair)
      continue
      ;;

    *)
      console_out "Usage: bootstrap-csgo.sh (install <GSLT> | update | repair)\n"
      console_out "Example: bootstrap-csgo.sh install 93ECDE6B7526D1CAA699DA32D7E7DBB0\n"
      console_out "Get a GSLT: https://steamcommunity.com/dev/managegameservers\n\n"
      exit 1
  esac

  if [ $1 == "install" ]; then
    console_out "Hold onto your butts."
    # Is EPEL enabled?
    CHK_EPEL=$(yum list installed | grep epel-release)
    if [ -z "$CHK_EPEL" ]; then
      console_out "Enabling EPEL repository\n"
      yum install -y epel-release
    fi

    # Update binaries
    console_out "Running Sytem Update\n"
    yum update -y && yum upgrade -y

    console_out "Checking packages\n"
    CHK_PKGS=(
      "sudo"
      "zsh"
      "git.x86_64"
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
    # Check arch, srcds always requires 32-bit libs
    if [ $(uname -m) == "x86_64" ]; then
      console_out "64-bit archictecture detected, forcing 32-bit C/C++ libraries\n"
      CHK_PKGS+=("glibc.i686" "libstdc++.i686")
    else
      console_out "32-bit architecture detected, using standard C/C++ libraries\n"
      CHK_PKGS+=("glibc" "libstdc++")
    fi
    # Check if any of these packages are already installed
    for i in "${CHK_PKGS[@]}"
    do
      CHK_PKG=$(yum list installed | grep $i)
      if [ -z "$CHK_PKG" ]; then
        console_out "Marking $i for installation\n"
        PKGS+=("$i")
      else
        console_out "Skipping $i\n"
      fi
    done

    # Install packages
    if [ -n "$PKGS" ]; then yum install -y ${PKGS[@]}; fi

    # Create service account if it doesn't exist
    console_out "Checking service account\n"
    if id "$SERVICE_USR" >/dev/null 2>&1; then
      console_out "Service account already exists\n"
    else
      console_out "Creating service account: $SERVICE_USR\n"
      useradd -d /home/$SERVICE_USR -m -s /bin/zsh $SERVICE_USR
    fi

    # Add firewalld exceptions
    CHK_FIREWALL=$(yum list installed | grep firewalld)
    if [ -n "$CHK_FIREWALL" ]; then
      console_out "Enabling and configuring firewalld\n"
      systemctl enable firewalld.service
      systemctl start firewalld.service
      console_out "Adding firewall rule for 27015/tcp: "
      firewall-cmd --zone=public --add-port=27015/tcp --permanent
      console_out "Adding firewall rule for 27015/udp: "
      firewall-cmd --zone=public --add-port=27015/udp --permanent
      console_out "Reloading firewall: "
      firewall-cmd --reload
    fi

    # Install SteamCMD
    if [ ! -f "$INSTALL_DIR/steamcmd/steamcmd.sh" ]; then
      console_out "Installing SteamCMD\n"
      if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        if [ ! -d "$INSTALL_DIR/steamcmd" ]; then mkdir $INSTALL_DIR/steamcmd; fi
      fi
      sudo -u $SERVICE_USR curl -sqL "$STEAMCMD_URL" | tar zxvf - -C $INSTALL_DIR/steamcmd
    fi

    # Install CS:GO
    if [ ! -d "$SRCDS_DIR" ]; then
      console_out "Installing CS:GO Dedicated Server\n"
      csgo_update
    fi

    # Create symlinks
    console_out "Creating symlinks... "
    if [ ! -d "/home/$SERVICE_USR/.steam" ]; then mkdir -p "/home/$SERVICE_USR/.steam/sdk32"; fi
    ln -s $INSTALL_DIR/steamcmd/linux32/steamclient.so /home/$SERVICE_USR/.steam/sdk32/steamclient.so
    printf "done\n"

    # Create addons dir
    if [ ! -d "$CSGO_DIR/addons" ]; then mkdir -p "$CSGO_DIR/addons"; fi

    # Build default configs
    F_AUTOEXEC="$CSGO_DIR/cfg/autoexec.cfg"
    if [ ! -f "$F_AUTOEXEC" ]; then
      console_out "Creating autoexec.cfg\n"
      echo "// autoexec.cfg" > $F_AUTOEXEC
      echo "sv_setsteamaccount \"$GSLTOKEN\"" >> $F_AUTOEXEC
      echo "log on" >> $F_AUTOEXEC
      echo "//rcon_password \"$(date +%s)\"" >> $F_AUTOEXEC
      echo "sv_cheats 0" >> $F_AUTOEXEC
      echo "sv_lan 0" >> $F_AUTOEXEC
      echo "exec banned_user.cfg" >> $F_AUTOEXEC
      echo "exec banned_ip.cfg" >> $F_AUTOEXEC
    fi

    F_SERVER="$CSGO_DIR/cfg/server.cfg"
    if [ ! -f "$F_SERVER" ]; then
      console_out "Creating server.cfg\n"
      echo "// server.cfg" > $F_SERVER
      echo "mp_autoteambalance 1" >> $F_SERVER
      echo "mp_limitteams 1" >> $F_SERVER
      echo "writeid" >> $F_SERVER
      echo "writeip" >> $F_SERVER
    fi

    # Build environment config file for systemd service
    F_SERVICECONF="$SRCDS_DIR/.csgo-service-conf"
    if [ ! -f "$F_SERVICECONF" ]; then
      echo "GAME=\"-game csgo\"" >> $F_SERVICECONF
      echo "AUTOUPDATE=\"-autoupdate\"" >> $F_SERVICECONF
      echo "TICKRATE=\"-tickrate 128\"" >> $F_SERVICECONF
      echo "CONSOLE=\"-console\"" >> $F_SERVICECONF
      echo "USERCON=\"-usercon\"" >> $F_SERVICECONF
      echo "TOKEN=\"+sv_setsteamaccount $GSLTOKEN\"" >> $F_SERVICECONF
      echo "NETPORTTRY=\"-net_port_try 1\"" >> $F_SERVICECONF
      echo "GAMETYPE=\"+game_type 0\"" >> $F_SERVICECONF
      echo "GAMEMODE=\"+game_mode 1\"" >> $F_SERVICECONF
      echo "MAPGROUP=\"+mapgroup mg_active\"" >> $F_SERVICECONF
      echo "MAP=\"+map de_mirage\"" >> $F_SERVICECONF
    fi

    # Build systemd service
    F_SERVICE="/etc/systemd/system/csgo.service"
    if [ ! -f "$F_SERVICE" ]; then
      console_out "Installing csgo.service\n"
      echo "[Unit]" >> $F_SERVICE
      echo "Description=CS:GO Dedicated Server" >> $F_SERVICE
      echo "After=network.target" >> $F_SERVICE
      echo -e "\n[Service]" >> $F_SERVICE
      echo "Type=simple" >> $F_SERVICE
      echo "User=$SERVICE_USR" >> $F_SERVICE
      echo "WorkingDirectory=/steam/csgo_ds" >> $F_SERVICE
      echo "Environment=\"LD_LIBRARY_PATH=$SRCDS_DIR:$SRCDS_DIR/bin\"" >> $F_SERVICE
      echo "EnvironmentFile=$SRCDS_DIR/.csgo-service-conf" >> $F_SERVICE
      echo "ExecStart=$SRCDS_DIR/srcds_run \${GAME} \${AUTOUPDATE} \${TICKRATE} \${CONSOLE} \${USERCON} \${TOKEN} \${NETPORTTRY} \${GAMETYPE} \${GAMEMODE} \${MAPGROUP} \${MAP}" >> $F_SERVICE
      echo "Restart=always" >> $F_SERVICE
      console_out "Reloading systemd... "
      systemctl daemon-reload
      printf "ok\n"
      console_out "Start: systemctl enable csgo && systemctl start csgo\n"
    fi
  fi

  # Run the updater
  # ! Experimental
  if [ $1 == "update" ]; then
    console_out "Stopping csgo.service... "
    systemctl stop csgo.service
    printf "ok\n"
    console_out "Checking for updates\n"
    csgo_update
    console_out "Starting csgo.service... "
    systemctl start csgo.service
    printf "ok\n"
  fi

  # Fix permissions
  if [[ $1 == "repair" ]] || [[ $1 == "install" ]]; then
    console_out "Changing ownership of $INSTALL_DIR to $SERVICE_USR\n"
    chown -R $SERVICE_USR:$SERVICE_USR $INSTALL_DIR
  fi

  console_out "Complete!\n"
}

function console_out() {
  printf "[Bootstrapper] : $1"
}

function csgo_update() {
  sudo -u $SERVICE_USR "$INSTALL_DIR/steamcmd/steamcmd.sh" "+login anonymous" "+force_install_dir $SRCDS_DIR" "+app_update 740 validate" "+quit"
}

# Incomplete
function backupcron_install() {
  console_out "Installing backup script\n"

  # Create backup directory
  if [ ! -d "$INSTALL_DIR/backup" ]; then mkdir -p "$INSTALL_DIR/backup"; fi

  # Build backup configuration file
  F_BACKUPCONF="$INSTALL_DIR/backup/csgo-backup.conf"
  if [ ! -f "$F_BACKUPCONF" ]; then
    console_out "Setting default backup locations... "
    echo "$CSGO_DIR/addons" > $F_BACKUPCONF
    echo "$CSGO_DIR/cfg" >> $F_BACKUPCONF
    echo "$CSGO_DIR/maps" >> $F_BACKUPCONF
    echo "$CSGO_DIR/scripts" >> $F_BACKUPCONF
    printf "done!\n"
  fi

  # Build backup script
  F_BACKUPCRON="/usr/local/bin/csgo-backup.sh"
  if [ ! -f "$F_BACKUPCRON" ]; then
    console_out "Generating backup script... "
    echo "#!/bin/bash" > $F_BACKUPCRON
    echo "tar czvf $INSTALL_DIR/backup/csgo-backup.tar.gz \$(</$INSTALL_DIR/backup/csgo-backup.conf" >> $F_BACKUPCRON
    printf "done!\n"
    console_out "Adding backup job to /etc/cron.d\n"
  fi
}

main "$@"
