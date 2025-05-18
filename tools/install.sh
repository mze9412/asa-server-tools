#!/bin/bash

userinstall=no
steamcmd_user=
showusage=no
migrateconfig=no
installservice=no

while [ -n "$1" ]; do
  case "$1" in
    --me)
      userinstall=yes
      steamcmd_user="--me"
    ;;
    -h|--help)
      showusage=yes
      break
    ;;
    --prefix=*)
      PREFIX="${1#--prefix=}"
    ;;
    --prefix)
      PREFIX="$2"
      shift
    ;;
    --exec-prefix=*)
      EXECPREFIX="${1#--exec-prefix=}"
    ;;
    --exec-prefix)
      EXECPREFIX="$2"
      shift
    ;;
    --data-prefix=*)
      DATAPREFIX="${1#--data-prefix=}"
    ;;
    --data-prefix)
      DATAPREFIX="$2"
      shift
    ;;
    --install-root=*)
      INSTALL_ROOT="${1#--install-root=}"
    ;;
    --install-root)
      INSTALL_ROOT="$2"
      shift
    ;;
    --bindir=*)
      BINDIR="${1#--bindir=}"
    ;;
    --bindir)
      BINDIR="$2"
      shift
    ;;
    --libexecdir=*)
      LIBEXECDIR="${1#--libexecdir=}"
    ;;
    --libexecdir)
      LIBEXECDIR="$2"
      shift
    ;;
    --datadir=*)
      DATADIR="${1#--datadir=}"
    ;;
    --datadir)
      DATADIR="$2"
      shift
    ;;
    --migrate-config)
      migrateconfig=yes
    ;;
    --install-service)
      installservice=yes
    ;;
    --install-proton-ge)
      installproton=yes
    ;;
    -*)
      echo "Invalid option '$1'"
      showusage=yes
      break;
    ;;
    *)
      if [ -n "$steamcmd_user" ]; then
        echo "Multiple users specified"
        showusage=yes
        break;
      elif getent passwd "$1" >/dev/null 2>&1; then
        steamcmd_user="$1"
      else
        echo "Invalid user '$1'"
        showusage=yes
        break;
      fi
    ;;
  esac
  shift
done

if [ "$userinstall" == "yes" ] && [ "$UID" -eq 0 ]; then
  echo "Refusing to perform user-install as root"
  showusage=yes
fi

if [ "$showusage" == "no" ] && [ -z "$steamcmd_user" ]; then
  echo "No user specified"
  showusage=yes
fi

if [ "$userinstall" == "yes" ]; then
  PREFIX="${PREFIX:-${HOME}}"
  EXECPREFIX="${EXECPREFIX:-${PREFIX}}"
  DATAPREFIX="${DATAPREFIX:-${PREFIX}/.local/share}"
  CONFIGFILE="${PREFIX}/.asamanager.cfg"
  INSTANCEDIR="${PREFIX}/.config/asamanager/instances"

  # COMPATDIR is in ~/.steam/steam/steamapps/compatdata
  COMPATDIR="${PREFIX}/.steam/steam/steamapps/compatdata"
else
  PREFIX="${PREFIX:-/usr/local}"
  EXECPREFIX="${EXECPREFIX:-${PREFIX}}"
  DATAPREFIX="${DATAPREFIX:-${PREFIX}/share}"
  CONFIGFILE="/etc/asamanager/asamanager.cfg"
  INSTANCEDIR="/etc/asamanager/instances"

  # COMPATDIR is in /home/STEAMCMD_USER/.steam/steam/steamapps/compatdata
  COMPATDIR="/home/$steamcmd_user/.steam/steam/steamapps/compatdata"
fi

BINDIR="${BINDIR:-${EXECPREFIX}/bin}"
LIBEXECDIR="${LIBEXECDIR:-${EXECPREFIX}/libexec/asamanager}"
DATADIR="${DATADIR:-${DATAPREFIX}/asamanager}"

if [ "$showusage" == "yes" ]; then
    echo "Usage: ./install.sh {<user>|--me} [OPTIONS]"
    echo "You must specify your system steam user who own steamcmd directory to install ASA Tools."
    echo "Specify the special used '--me' to perform a user-install."
    echo
    echo "<user>          The user asamanager should be run as"
    echo
    echo "Option          Description"
    echo "--help, -h      Show this help text"
    echo "--me            Perform a user-install"
    echo "--prefix        Specify the prefix under which to install asamanager"
    echo "                [PREFIX=${PREFIX}]"
    echo "--exec-prefix   Specify the prefix under which to install executables"
    echo "                [EXECPREFIX=${EXECPREFIX}]"
    echo "--data-prefix   Specify the prefix under which to install support files"
    echo "                [DATAPREFIX=${DATAPREFIX}]"
    echo "--install-root  Specify the staging directory in which to perform the install"
    echo "                [INSTALL_ROOT=${INSTALL_ROOT}]"
    echo "--bindir        Specify the directory under which to install executables"
    echo "                [BINDIR=${BINDIR}]"
    echo "--libexecdir    Specify the directory under which to install executable support files"
    echo "                [LIBEXECDIR=${LIBEXECDIR}]"
    echo "--datadir       Specify the directory under which to install support files"
    echo "                [DATADIR=${DATADIR}]"
    echo "--install-service"
    echo "                Install the service"
    echo "--install-proton-ge"
    echo "                Downloads and installs Proton-GE for use with asamanager. If you do not use this flag you have to install your own version of Proton."
    exit 1
fi

if [ "$userinstall" == "yes" ]; then
    # Copy asamanager to ~/bin
    mkdir -p "${INSTALL_ROOT}${BINDIR}"
    cp asamanager "${INSTALL_ROOT}${BINDIR}/asamanager"
    chmod +x "${INSTALL_ROOT}${BINDIR}/asamanager"

    # Create a folder in ~/.local/share to store asamanager support files
    mkdir -p "${INSTALL_ROOT}${DATADIR}"

    # Copy the uninstall script to ~/.local/share/asamanager
    cp uninstall-user.sh "${INSTALL_ROOT}${DATADIR}/asamanager-uninstall.sh"
    chmod +x "${INSTALL_ROOT}${DATADIR}/asamanager-uninstall.sh"
    sed -i -e "s|^BINDIR=.*|BINDIR=\"${BINDIR}\"|" \
           -e "s|^DATADIR=.*|DATADIR=\"${DATADIR}\"|" \
           "${INSTALL_ROOT}${DATADIR}/asamanager-uninstall.sh"

    # Create a folder in ~/logs to let Ark tools write its own log files
    mkdir -p "${INSTALL_ROOT}${PREFIX}/logs/arktools"

    # Create a folder in ~/.config/arkamanger to hold instance configs
    mkdir -p "${INSTALL_ROOT}${INSTANCEDIR}"

    # Copy example instance config
    cp instance.cfg.example "${INSTALL_ROOT}/${INSTANCEDIR}/instance.cfg.example"
    # Change the defaults in the new instance config template
    sed -i -e "s|\"/home/steam|\"${PREFIX}|" \
           "${INSTALL_ROOT}${INSTANCEDIR}/instance.cfg.example"

    # Copy asamanager.cfg to ~/.asamanager.cfg.NEW
    cp asamanager.cfg "${INSTALL_ROOT}${CONFIGFILE}.example"
    # Change the defaults in the new config file
    sed -i -e "s|^steamcmd_user=\"steam\"|steamcmd_user=\"--me\"|" \
           -e "s|\"/home/steam|\"${PREFIX}|" \
           -e "s|/var/log/arktools|${PREFIX}/logs/arktools|" \
           -e "s|^install_bindir=.*|install_bindir=\"${BINDIR}\"|" \
           -e "s|^install_libexecdir=.*|install_libexecdir=\"${LIBEXECDIR}\"|" \
           -e "s|^install_datadir=.*|install_datadir=\"${DATADIR}\"|" \
           "${INSTALL_ROOT}${CONFIGFILE}.example"

    # Copy asamanager.cfg to ~/.asamanager.cfg if it doesn't already exist
    if [ -f "${INSTALL_ROOT}${CONFIGFILE}" ]; then
      SUFFIX=
      if [ "$migrateconfig" = "no" ]; then
        SUFFIX=".NEW"
        cp "${INSTALL_ROOT}${CONFIGFILE}" "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}"
      fi

      bash ./migrate-config.sh "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}"
      bash ./migrate-main-instance.sh "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}" "${INSTALL_ROOT}${INSTANCEDIR}/main.cfg${SUFFIX}"

      echo "A previous version of ASA Server Tools was detected in your system, your old configuration was not overwritten. You may need to manually update it."
      echo "A copy of the new configuration file was included in '${CONFIGFILE}.NEW'. Make sure to review any changes and update your config accordingly!"
      exit 2
    else
      cp -n "${INSTALL_ROOT}${CONFIGFILE}.example" "${INSTALL_ROOT}${CONFIGFILE}"
      cp -n "${INSTALL_ROOT}/${INSTANCEDIR}/instance.cfg.example" "${INSTALL_ROOT}/${INSTANCEDIR}/main.cfg"
    fi
else
    # Copy asamanager to /usr/bin and set permissions
    cp asamanager "${INSTALL_ROOT}${BINDIR}/asamanager"
    chmod +x "${INSTALL_ROOT}${BINDIR}/asamanager"

    # Copy the uninstall script to ~/.local/share/asamanager
    mkdir -p "${INSTALL_ROOT}${LIBEXECDIR}"
    cp uninstall.sh "${INSTALL_ROOT}${LIBEXECDIR}/asamanager-uninstall.sh"
    chmod +x "${INSTALL_ROOT}${LIBEXECDIR}/asamanager-uninstall.sh"
    sed -i -e "s|^BINDIR=.*|BINDIR=\"${BINDIR}\"|" \
           -e "s|^LIBEXECDIR=.*|LIBEXECDIR=\"${LIBEXECDIR}\"|" \
           -e "s|^DATADIR=.*|DATADIR=\"${DATADIR}\"|" \
           "${INSTALL_ROOT}${LIBEXECDIR}/asamanager-uninstall.sh"

    if [ "$installservice" = "yes" ]; then
      # Copy arkdaemon to /etc/init.d ,set permissions and add it to boot
      if [ -f /lib/lsb/init-functions ]; then
        # on debian 8, sysvinit and systemd are present. If systemd is available we use it instead of sysvinit
        if [ -f /etc/systemd/system.conf ]; then   # used by systemd
          mkdir -p "${INSTALL_ROOT}${LIBEXECDIR}"
          cp systemd/asamanager.init "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
          sed -i "s|^DAEMON=\"/usr/bin/|DAEMON=\"${BINDIR}/|" "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
          chmod +x "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
          cp systemd/asamanager.service "${INSTALL_ROOT}/etc/systemd/system/asamanager.service"
          sed -i "s|=/usr/libexec/asamanager/|=${LIBEXECDIR}/|" "${INSTALL_ROOT}/etc/systemd/system/asamanager.service"
          cp systemd/asamanager@.service "${INSTALL_ROOT}/etc/systemd/system/asamanager@.service"
          sed -i "s|=/usr/bin/|=${BINDIR}/|;s|=steam$|=${steamcmd_user}|" "${INSTALL_ROOT}/etc/systemd/system/asamanager@.service"
          if [ -z "${INSTALL_ROOT}" ]; then
            systemctl daemon-reload
            systemctl enable asamanager.service
            echo "Ark server will now start on boot, if you want to remove this feature run the following line"
            echo "systemctl disable asamanager.service"
          fi
        else  # systemd not present, so use sysvinit
          cp lsb/arkdaemon "${INSTALL_ROOT}/etc/init.d/asamanager"
          chmod +x "${INSTALL_ROOT}/etc/init.d/asamanager"
          sed -i "s|^DAEMON=\"/usr/bin/|DAEMON=\"${BINDIR}/|" "${INSTALL_ROOT}/etc/init.d/asamanager"
          # add to startup if the system use sysinit
          if [ -x /usr/sbin/update-rc.d ] && [ -z "${INSTALL_ROOT}" ]; then
            update-rc.d asamanager defaults
            echo "Ark server will now start on boot, if you want to remove this feature run the following line"
            echo "update-rc.d -f asamanager remove"
          fi
        fi
      elif [ -f /etc/rc.d/init.d/functions ]; then
        # on RHEL 7, sysvinit and systemd are present. If systemd is available we use it instead of sysvinit
        if [ -f /etc/systemd/system.conf ]; then   # used by systemd
          mkdir -p "${INSTALL_ROOT}${LIBEXECDIR}"
          cp systemd/asamanager.init "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
          sed -i "s|^DAEMON=\"/usr/bin/|DAEMON=\"${BINDIR}/|" "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
          chmod +x "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
          cp systemd/asamanager.service "${INSTALL_ROOT}/etc/systemd/system/asamanager.service"
          sed -i "s|=/usr/libexec/asamanager/|=${LIBEXECDIR}/|" "${INSTALL_ROOT}/etc/systemd/system/asamanager.service"
          cp systemd/asamanager@.service "${INSTALL_ROOT}/etc/systemd/system/asamanager@.service"
          sed -i "s|=/usr/bin/|=${BINDIR}/|;s|=steam$|=${steamcmd_user}|" "${INSTALL_ROOT}/etc/systemd/system/asamanager@.service"
          if [ -z "${INSTALL_ROOT}" ]; then
            systemctl daemon-reload
            systemctl enable asamanager.service
            echo "Ark server will now start on boot, if you want to remove this feature run the following line"
            echo "systemctl disable asamanager.service"
          fi
        else # systemd not preset, so use sysvinit
          cp redhat/arkdaemon "${INSTALL_ROOT}/etc/rc.d/init.d/asamanager"
          chmod +x "${INSTALL_ROOT}/etc/rc.d/init.d/asamanager"
          sed -i "s@^DAEMON=\"/usr/bin/@DAEMON=\"${BINDIR}/@" "${INSTALL_ROOT}/etc/rc.d/init.d/asamanager"
          if [ -x /sbin/chkconfig ] && [ -z "${INSTALL_ROOT}" ]; then
            chkconfig --add asamanager
            echo "Ark server will now start on boot, if you want to remove this feature run the following line"
            echo "chkconfig asamanager off"
          fi
        fi
      elif [ -f /sbin/runscript ]; then
        cp openrc/arkdaemon "${INSTALL_ROOT}/etc/init.d/asamanager"
        chmod +x "${INSTALL_ROOT}/etc/init.d/asamanager"
        sed -i "s@^DAEMON=\"/usr/bin/@DAEMON=\"${BINDIR}/@" "${INSTALL_ROOT}/etc/init.d/asamanager"
        if [ -x /sbin/rc-update ] && [ -z "${INSTALL_ROOT}" ]; then
          rc-update add asamanager default
          echo "Ark server will now start on boot, if you want to remove this feature run the following line"
          echo "rc-update del asamanager default"
        fi
      elif [ -f /etc/systemd/system.conf ]; then   # used by systemd
        mkdir -p "${INSTALL_ROOT}${LIBEXECDIR}"
        cp systemd/asamanager.init "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
        sed -i "s|^DAEMON=\"/usr/bin/|DAEMON=\"${BINDIR}/|" "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
        chmod +x "${INSTALL_ROOT}${LIBEXECDIR}/asamanager.init"
        cp systemd/asamanager.service "${INSTALL_ROOT}/etc/systemd/system/asamanager.service"
        sed -i "s|=/usr/libexec/asamanager/|=${LIBEXECDIR}/|" "${INSTALL_ROOT}/etc/systemd/system/asamanager.service"
        cp systemd/asamanager@.service "${INSTALL_ROOT}/etc/systemd/system/asamanager@.service"
        sed -i "s|=/usr/bin/|=${BINDIR}/|;s|=steam$|=${steamcmd_user}|" "${INSTALL_ROOT}/etc/systemd/system/asamanager@.service"
        if [ -z "${INSTALL_ROOT}" ]; then
          systemctl daemon-reload
          systemctl enable asamanager.service
          echo "Ark server will now start on boot, if you want to remove this feature run the following line"
          echo "systemctl disable asamanager.service"
        fi
      fi
    fi

    # Create a folder in /var/log to let Ark tools write its own log files
    mkdir -p "${INSTALL_ROOT}/var/log/arktools"
    chown "$steamcmd_user" "${INSTALL_ROOT}/var/log/arktools"

    # Create a folder in /etc/asamanager to hold instance config files
    mkdir -p "${INSTALL_ROOT}${INSTANCEDIR}"
    chown "$steamcmd_user" "${INSTALL_ROOT}${INSTANCEDIR}"

    # Copy example instance config
    cp instance.cfg.example "${INSTALL_ROOT}${INSTANCEDIR}/instance.cfg.example"
    chown "$steamcmd_user" "${INSTALL_ROOT}${INSTANCEDIR}/instance.cfg.example"
    # Change the defaults in the new instance config template
    sed -i -e "s|\"/home/steam|\"/home/$steamcmd_user|" \
           "${INSTALL_ROOT}${INSTANCEDIR}/instance.cfg.example"

    # Copy asamanager bash_completion into /etc/bash_completion.d/
    mkdir -p "${INSTALL_ROOT}/etc/bash_completion.d"
    cp bash_completion/asamanager "${INSTALL_ROOT}/etc/bash_completion.d/asamanager"

    # Copy asamanager.cfg inside linux configuation folder if it doesn't already exists
    mkdir -p "${INSTALL_ROOT}/etc/asamanager"
    chown "$steamcmd_user" "${INSTALL_ROOT}/etc/asamanager"
    cp asamanager.cfg "${INSTALL_ROOT}${CONFIGFILE}.example"
    chown "$steamcmd_user" "${INSTALL_ROOT}${CONFIGFILE}.example"
    sed -i -e "s|^steamcmd_user=\"steam\"|steamcmd_user=\"$steamcmd_user\"|" \
           -e "s|\"/home/steam|\"/home/$steamcmd_user|" \
           -e "s|^install_bindir=.*|install_bindir=\"${BINDIR}\"|" \
           -e "s|^install_libexecdir=.*|install_libexecdir=\"${LIBEXECDIR}\"|" \
           -e "s|^install_datadir=.*|install_datadir=\"${DATADIR}\"|" \
           "${INSTALL_ROOT}${CONFIGFILE}.example"

    if [ -f "${INSTALL_ROOT}${CONFIGFILE}" ]; then
      SUFFIX=
      if [ "$migrateconfig" = "no" ]; then
        SUFFIX=".NEW"
        cp "${INSTALL_ROOT}${CONFIGFILE}" "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}"
      fi

      bash ./migrate-config.sh "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}"
      bash ./migrate-main-instance.sh "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}" "${INSTALL_ROOT}${INSTANCEDIR}/main.cfg${SUFFIX}"

      echo "A previous version of ASA Server Tools was detected in your system, your old configuration was not overwritten. You may need to manually update it."
      echo "A copy of the new configuration file was included in /etc/asamanager. Make sure to review any changes and update your config accordingly!"
      exit 2
    else
      cp -n "${INSTALL_ROOT}${CONFIGFILE}.example" "${INSTALL_ROOT}${CONFIGFILE}"
      chown "$steamcmd_user" "${INSTALL_ROOT}${CONFIGFILE}"
      cp -n "${INSTALL_ROOT}/${INSTANCEDIR}/instance.cfg.example" "${INSTALL_ROOT}/${INSTANCEDIR}/main.cfg"
      chown "$steamcmd_user" "${INSTALL_ROOT}${INSTANCEDIR}/main.cfg"
    fi
fi

if [ "$installproton" = "yes" ]; then
  PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-27/GE-Proton9-27.tar.gz"
  PROTON_TGZ="$(basename "$PROTON_URL")"
  PROTON_NAME="$(basename "$PROTON_TGZ" ".tar.gz")"

  # use COMPATDIR as base directory for PROTON_GE logic below
  if [ ! -e "$COMPATDIR/$PROTON_TGZ" ]; then
    # Create a directory to store the downloaded Proton
    [ -d "/home/steam/game-resources" ] || sudo -u steam mkdir -p "/home/steam/game-resources"
    wget "$PROTON_URL" -O "/home/steam/game-resources/$PROTON_TGZ"
  fi
  
  STEAMDIR="$COMPATDIR/.local/share/Steam"
  # Extract GE Proton into this user's Steam path
  [ -d "$STEAMDIR/compatibilitytools.d" ] || sudo -u steam mkdir -p "$STEAMDIR/compatibilitytools.d"
  sudo -u steam tar -x -C "$STEAMDIR/compatibilitytools.d/" -f "/home/steam/game-resources/$PROTON_TGZ"

  # Install default prefix into game compatdata path
  [ -d "$STEAMDIR/steamapps/compatdata" ] || sudo -u steam mkdir -p "$STEAMDIR/steamapps/compatdata"
  [ -d "$STEAMDIR/steamapps/compatdata/2430930" ] || sudo -u steam cp "$STEAMDIR/compatibilitytools.d/$PROTON_NAME/files/share/default_pfx" "$STEAMDIR/steamapps/compatdata/2430930" -r
fi

exit 0
