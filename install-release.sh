#!/bin/bash

# The files installed by the script conform to the Filesystem Hierarchy Standard:
# https://wiki.linuxfoundation.org/lsb/fhs

# The URL of the script project is:
# https://github.com/v2fly/fhs-install-v2ray

# The URL of the script is:
# https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh

# If the script executes incorrectly, go to:
# https://github.com/v2fly/fhs-install-v2ray/issues

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export DAT_PATH='/usr/local/share/v2ray'
DAT_PATH=${DAT_PATH:-/usr/local/share/v2ray}

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export JSON_PATH='/usr/local/etc/v2ray'
JSON_PATH=${JSON_PATH:-/usr/local/etc/v2ray}

# Set this variable only if you are starting v2ray with multiple configuration files:
# export JSONS_PATH='/usr/local/etc/v2ray'

# Set this variable only if you want this script to check all the systemd unit file:
# export check_all_service_files='yes'
echo "ulimit -n 65535"  >>/etc/profile
source  /etc/profile
echo "* soft nofile 51200">>/etc/security/limits.conf
echo "* hard nofile 51200">>/etc/security/limits.conf
wget --no-check-certificate https://raw.githubusercontent.com/goudaozhu/v2ray/main/deletelog.sh  && chmod +x  deletelog.sh
curl() {
  $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
}

systemd_cat_config() {
  if systemd-analyze --help | grep -qw 'cat-config'; then
    systemd-analyze --no-pager cat-config "$@"
    echo
  else
    echo "${aoi}~~~~~~~~~~~~~~~~"
    cat "$@" "$1".d/*
    echo "${aoi}~~~~~~~~~~~~~~~~"
    echo "${red}warning: ${green}The systemd version on the current operating system is too low."
    echo "${red}warning: ${green}Please consider to upgrade the systemd or the operating system.${reset}"
    echo
  fi
}

check_if_running_as_root() {
  # If you want to run as another user, please modify $UID to be owned by this user
  if [[ "$UID" -ne '0' ]]; then
    echo "error: You must run this script as root!"
    exit 1
  fi
}

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='32'
        ;;
      'amd64' | 'x86_64')
        MACHINE='64'
        ;;
      'armv5tel')
        MACHINE='arm32-v5'
        ;;
      'armv6l')
        MACHINE='arm32-v6'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm32-v7a'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64-v8a'
        ;;
      'mips')
        MACHINE='mips32'
        ;;
      'mipsle')
        MACHINE='mips32le'
        ;;
      'mips64')
        MACHINE='mips64'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'ppc64')
        MACHINE='ppc64'
        ;;
      'ppc64le')
        MACHINE='ppc64le'
        ;;
      'riscv64')
        MACHINE='riscv64'
        ;;
      's390x')
        MACHINE='s390x'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
    # Do not combine this judgment condition with the following judgment condition.
    ## Be aware of Linux distribution like Gentoo, which kernel supports switch between Systemd and OpenRC.
    ### Refer: https://github.com/v2fly/fhs-install-v2ray/issues/84#issuecomment-688574989
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
      true
    elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
      true
    else
      echo "error: Only Linux distributions using systemd are supported."
      exit 1
    fi
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}

## Demo function for processing parameters
judgment_parameters() {
  while [[ $# > 0 ]];do
    key="$1"
    case $key in
        -p|--proxy)
        PROXY="-x ${2}"
        shift # past argument
        ;;
        -h|--help)
        HELP="1"
        ;;
        -f|--force)
        FORCE="1"
        ;;
        -c|--check)
        CHECK="1"
        ;;
        --remove)
        REMOVE="1"
        ;;
        --version)
        VERSION="$2"
        shift
        ;;
        --extract)
        VSRC_ROOT="$2"
        shift
        ;;
        --extractonly)
        EXTRACT_ONLY="1"
        ;;
        -l|--local)
        LOCAL_FILE="$2"
        LOCAL_INSTALL="1"
        shift
        ;;
        --errifuptodate)
        ERROR_IF_UPTODATE="1"
        ;;
        --panelurl)
        PANELURL="$2"
        ;;
        --panelkey)
        PANELKEY="$2"
        ;;
        --nodeid)
        NODEID="$2"
        ;;
        --downwithpanel)
        DOWNWITHPANEL="$2"
        ;;
        --mysqlhost)
        MYSQLHOST="$2"
        ;;
        --mysqldbname)
        MYSQLDBNAME="$2"
        ;;
        --mysqluser)
        MYSQLUSR="$2"
        ;;
        --mysqlpasswd)
        MYSQLPASSWD="$2"
        ;;
        --mysqlport)
        MYSQLPORT="$2"
        ;;
        --speedtestrate)
        SPEEDTESTRATE="$2"
        ;;
        --paneltype)
        PANELTYPE="$2"
        ;;
        --usemysql)
        USEMYSQL="$2"
        ;;
        --ldns)
        LDNS="$2"
        ;;
        --cfkey)
        CFKEY="$2"
        ;;
        --cfemail)
        CFEMAIL="$2"
        ;;
         --alikey)
        ALiKey="$2"
        ;;
        --alisecret)
        ALiSecret="$2"
        ;;
        --nodeuserlimited)
        NODEUSERLIMITED="$2"
        ;;
        --useip)
        USEIP="$2"
        ;;
        --muregex)
        MUREGEX="$2"
        ;;
        --musuffix)
        MUSUFFIX="$2"
        ;;
         --proxytcp)
        PROXYTCP="$2"
        ;;
         --cachedurationsec)
        CacheDurationSec="$2"
        ;;
        --sendthrough)
        SendThrough="$2" 
        ;;
        --cftoken)
        CFToken="$2" 
        ;;
        --cfaccountid)
        CFAccountID="$2" 
        ;;
        --cfzoneid)
        CFZoneID="$2"
        ;;
        --dns)
        DNS="$2"
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done
}
install_software() {
  package_name="$1"
  file_to_detect="$2"
  type -P "$file_to_detect" > /dev/null 2>&1 && return
  if ${PACKAGE_MANAGEMENT_INSTALL} "$package_name"; then
    echo "info: $package_name is installed."
  else
    echo "error: Installation of $package_name failed, please check your network."
    exit 1
  fi
}

get_version() {
  # 0: Install or update V2Ray.
  # 1: Installed or no new version of V2Ray.
  # 2: Install the specified version of V2Ray.
  if [[ -n "$VERSION" ]]; then
    RELEASE_VERSION="v${VERSION#v}"
    return 2
  fi
  # Determine the version number for V2Ray installed from a local file
  if [[ -f '/usr/local/bin/v2ray' ]]; then
    VERSION="$(/usr/local/bin/v2ray -version | awk 'NR==1 {print $2}')"
    CURRENT_VERSION="v${VERSION#v}"
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
      RELEASE_VERSION="$CURRENT_VERSION"
      return
    fi
  fi
  # Get V2Ray release version number
  TMP_FILE="$(mktemp)"
  if ! curl -x "${PROXY}" -sS -H "Accept: application/vnd.github.v3+json" -o "$TMP_FILE" 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest'; then
    "rm" "$TMP_FILE"
    echo 'error: Failed to get release list, please check your network.'
    exit 1
  fi
  RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print $4}')"
  "rm" "$TMP_FILE"
  RELEASE_VERSION="v${RELEASE_LATEST#v}"
  # Compare V2Ray version numbers
  if [[ "$RELEASE_VERSION" != "$CURRENT_VERSION" ]]; then
    RELEASE_VERSIONSION_NUMBER="${RELEASE_VERSION#v}"
    RELEASE_MAJOR_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER%%.*}"
    RELEASE_MINOR_VERSION_NUMBER="$(echo "$RELEASE_VERSIONSION_NUMBER" | awk -F '.' '{print $2}')"
    RELEASE_MINIMUM_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER##*.}"
    # shellcheck disable=SC2001
    CURRENT_VERSIONSION_NUMBER="$(echo "${CURRENT_VERSION#v}" | sed 's/-.*//')"
    CURRENT_MAJOR_VERSION_NUMBER="${CURRENT_VERSIONSION_NUMBER%%.*}"
    CURRENT_MINOR_VERSION_NUMBER="$(echo "$CURRENT_VERSIONSION_NUMBER" | awk -F '.' '{print $2}')"
    CURRENT_MINIMUM_VERSION_NUMBER="${CURRENT_VERSIONSION_NUMBER##*.}"
    if [[ "$RELEASE_MAJOR_VERSION_NUMBER" -gt "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
      return 0
    elif [[ "$RELEASE_MAJOR_VERSION_NUMBER" -eq "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
      if [[ "$RELEASE_MINOR_VERSION_NUMBER" -gt "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
        return 0
      elif [[ "$RELEASE_MINOR_VERSION_NUMBER" -eq "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
        if [[ "$RELEASE_MINIMUM_VERSION_NUMBER" -gt "$CURRENT_MINIMUM_VERSION_NUMBER" ]]; then
          return 0
        else
          return 1
        fi
      else
        return 1
      fi
    else
      return 1
    fi
  elif [[ "$RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
    return 1
  fi
}

download_v2ray() {
  DOWNLOAD_LINK="wget https://raw.githubusercontent.com/goudaozhu/v2ray/main/v2ray.zip"
  echo "Downloading V2Ray archive: $DOWNLOAD_LINK"
  if ! curl -x "${PROXY}" -R -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  echo "Downloading verification file for V2Ray archive: $DOWNLOAD_LINK.dgst"
  if ! curl -x "${PROXY}" -sSR -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
    echo 'error: This version does not support verification. Please replace with another version.'
    return 1
  fi

  # Verification of V2Ray archive
  for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
    SUM="$(${LISTSUM}sum "$ZIP_FILE" | sed 's/ .*//')"
    CHECKSUM="$(grep ${LISTSUM^^} "$ZIP_FILE".dgst | grep "$SUM" -o -a | uniq)"
    if [[ "$SUM" != "$CHECKSUM" ]]; then
      echo 'error: Check failed! Please check your network or try again.'
      return 1
    fi
  done
}

decompression() {
  if ! unzip -q "$1" -d "$TMP_DIRECTORY"; then
    echo 'error: V2Ray decompression failed.'
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
  fi
  echo "info: Extract the V2Ray package to $TMP_DIRECTORY and prepare it for installation."
}

install_file() {
  NAME="$1"
  if [[ "$NAME" == 'v2ray' ]] || [[ "$NAME" == 'v2ctl' ]]; then
    install -m 755 "${TMP_DIRECTORY}/$NAME" "/usr/local/bin/$NAME"
  elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
    install -m 644 "${TMP_DIRECTORY}/$NAME" "${DAT_PATH}/$NAME"
  fi
}

install_v2ray() {
  # Install V2Ray binary to /usr/local/bin/ and $DAT_PATH
  install_file v2ray
  install_file v2ctl
  install -d "$DAT_PATH"
  # If the file exists, geoip.dat and geosite.dat will not be installed or updated
  if [[ ! -f "${DAT_PATH}/.undat" ]]; then
    install_file geoip.dat
    install_file geosite.dat
  fi

  # Install V2Ray configuration file to $JSON_PATH
  # shellcheck disable=SC2153
  if [[ -z "$JSONS_PATH" ]] && [[ ! -d "$JSON_PATH" ]]; then
    install -d "$JSON_PATH"
    # echo "{}" > "${JSON_PATH}/config.json"
    cp "${TMP_DIRECTORY}/vpoint_vmess_freedom.json" "${JSON_PATH}/config.json"
    echo  ${PANELURL}  ${PANELKEY}
    if [ ! -z "${PANELURL}" ]
    then
          sed -i "s|"https://google.com"|"${PANELURL}"|g" "${JSON_PATH}/config.json"
          echo "${green}PANELURL:${PANELURL}"
    fi
    if [ ! -z "${PANELKEY}" ]
    then
           sed -i "s/"55fUxDGFzH3n"/"${PANELKEY}"/g" "${JSON_PATH}/config.json"
           echo "${green}PANELKEY:${PANELKEY}"

    fi
    if [ ! -z "${NODEID}" ]
    then
            sed -i "s/123456,/${NODEID},/g" "${JSON_PATH}/config.json"
            echo "${green}NODEID:${NODEID}"

    fi

    if [ ! -z "${DOWNWITHPANEL}" ]
    then
          sed -i "s|\"downWithPanel\": 1|\"downWithPanel\": ${DOWNWITHPANEL}|g" "${JSON_PATH}/config.json"
          echo "${green}DOWNWITHPANEL:${DOWNWITHPANEL}"
    fi

    if [ ! -z "${MYSQLHOST}" ]
    then
            sed -i "s|"https://bing.com"|"${MYSQLHOST}"|g" "${JSON_PATH}/config.json"
           echo "${green}MYSQLHOST:${MYSQLHOST}"

    fi
    if [ ! -z "${MYSQLDBNAME}" ]
    then
            sed -i "s/"demo_dbname"/"${MYSQLDBNAME}"/g" "${JSON_PATH}/config.json"
            echo "${green}MYSQLDBNAME:${MYSQLDBNAME}"

    fi
    if [ ! -z "${MYSQLUSR}" ]
    then
          sed -i "s|\"demo_user\"|\"${MYSQLUSR}\"|g" "${JSON_PATH}/config.json"
          echo "${green}MYSQLUSR:${MYSQLUSR}"
    fi
    if [ ! -z "${MYSQLPASSWD}" ]
    then
           sed -i "s/"demo_dbpassword"/"${MYSQLPASSWD}"/g" "${JSON_PATH}/config.json"
           echo "${green}MYSQLPASSWD:${MYSQLPASSWD}"

    fi
    if [ ! -z "${MYSQLPORT}" ]
    then
            sed -i "s/3306,/${MYSQLPORT},/g" "${JSON_PATH}/config.json"
            echo "${green}MYSQLPORT:${MYSQLPORT}"

    fi

    if [ ! -z "${SPEEDTESTRATE}" ]
    then
            sed -i "s|\"SpeedTestCheckRate\": 6|\"SpeedTestCheckRate\": ${SPEEDTESTRATE}|g" "${JSON_PATH}/config.json"
            echo "${green}SPEEDTESTRATE:${SPEEDTESTRATE}"

    fi
     if [ ! -z "${CHECKRATE}" ]
    then
            sed -i "s|\"CHECKRATE\": 60|\"CHECKRATE\": ${CHECKRATE}|g" "${JSON_PATH}/config.json"
            echo "${green}CHECKRATE:${CHECKRATE}"

    fi
    
    if [ ! -z "${PANELTYPE}" ]
    then
            sed -i "s|\"paneltype\": 0|\"paneltype\": ${PANELTYPE}|g" "${JSON_PATH}/config.json"
            echo "${green}PANELTYPE:${PANELTYPE}"

    fi
    if [ ! -z "${USEMYSQL}" ]
    then
            sed -i "s|\"usemysql\": 0|\"usemysql\": ${USEMYSQL}|g" "${JSON_PATH}/config.json"
            echo "${green}USEMYSQL:${USEMYSQL}"

    fi
    if [ ! -z "${LDNS}" ]
    then
            sed -i "s|\"localhost\"|\"${LDNS}\"|g" "${JSON_PATH}/config.json"
             echo "${green}DNS:${LDNS}"
    fi
    if [ ! -z "${CFKEY}" ]
    then
      sed -i "s|\"bbbbbbbbbbbbbbbbbb\"|\"${CFKEY}\"|g" "${JSON_PATH}/config.json"
        echo "${green}CFKEY:${CFKEY}"
    fi
    if [ ! -z "${CFEMAIL}" ]
    then
      sed -i "s|\"v2ray@v2ray.com\"|\"${CFEMAIL}\"|g" "${JSON_PATH}/config.json"
        echo "${green}CFEMAIL:${CFEMAIL}"
    fi
    if [ ! -z "${ALiKey}" ]
    then
    sed -i "s|\"sdfsdfsdfljlbjkljlkjsdfoiwje\"|\"${ALiKey}\"|g" "${JSON_PATH}/config.json"
     echo "${green}ALiKey:${ALiKey}"
    fi
    if [ ! -z "${ALiSecret}" ]
    then
    sed -i "s|\"jlsdflanljkljlfdsaklkjflsa\"|\"${ALiSecret}\"|g" "${JSON_PATH}/config.json"
      echo "${green}ALiSecret:${ALiSecret}"
    fi
    if [ ! -z "${NODEUSERLIMITED}" ]
    then
            sed -i "s|\"NodeUserLimited\": 4|\"NodeUserLimited\": ${NODEUSERLIMITED}|g" "${JSON_PATH}/config.json"
            echo "${green}NODEUSERLIMITED:${NODEUSERLIMITED}"

    fi

    if [ ! -z "${USEIP}" ]
    then
            sed -i "s|\"UseIPv4\"|\"${UseIP}\"|g" "${JSON_PATH}/config.json"
            echo "${green}USEIP:${USEIP}"

    fi

    if [ ! -z "${MUREGEX}" ]
    then
           sed -i "s|\"%5m%id.%suffix\"|\"${MUREGEX}\"|g" "${JSON_PATH}/config.json"
            echo "${green}MUREGEX:${MUREGEX}"

    fi

    if [ ! -z "${MUSUFFIX}" ]
    then
           sed -i "s|\"microsoft.com\"|\"${MUSUFFIX}\"|g" "${JSON_PATH}/config.json"
           echo "${green}MUSUFFIX:${MUSUFFIX}"

    fi
    
    if [ ! -z "${PROXYTCP}" ]
    then
            sed -i "s|\"proxy_tcp\": 0|\"proxy_tcp\": ${PROXYTCP}|g" "${JSON_PATH}/config.json"
            echo "${green}PROXYTCP:${PROXYTCP}"

    fi
    if [ ! -z "${CacheDurationSec}" ]
    then
            sed -i "s|\"cache_duration_sec\": 120|\"cache_duration_sec\": ${CacheDurationSec}|g" "${JSON_PATH}/config.json"
            echo "${green}CacheDurationSec:${CacheDurationSec}"

    fi  
    if [ ! -z "${SendThrough}" ]
    then
      sed -i "s|\"0.0.0.0\"|\"${SendThrough}\"|g" "${JSON_PATH}/config.json"
      echo "${green}SendThrough:${SendThrough}"
    fi

    if [ ! -z "${CFToken}" ]
    then
      sed -i "s|\"cf_token\": \"679asdf\"|\"cf_token\": \"${CFToken}\"|g" "${JSON_PATH}/config.json"
      echo "${green}CFToken:${CFToken}"

    fi
    if [ ! -z "${CFAccountID}" ]
    then
      sed -i "s|\"cf_accound_id\": \"asdf1234\"|\"cf_accound_id\": \"${CFAccountID}\"|g" "${JSON_PATH}/config.json"
      echo "${green}CFAccountID:${CFAccountID}"
    fi
    if [ ! -z "${CFZoneID}" ]
    then
      sed -i "s|\"cf_zone_id\": \"owieur123\"|\"cf_zone_id\": \"${CFZoneID}\"|g" "${JSON_PATH}/config.json"
      echo "${green}CFZoneID:${CFZoneID}"
    fi
    if [ ! -z "${DNS}" ]
    then
      sed -i "s|\"8.8.8.8\"|\"${DNS}\"|g" "${JSON_PATH}/config.json"
      echo "${green}DNS:${DNS}"
    fi
    CONFIG_NEW='1'
  fi

  # Install V2Ray configuration file to $JSONS_PATH
  if [[ -n "$JSONS_PATH" ]] && [[ ! -d "$JSONS_PATH" ]]; then
    install -d "$JSONS_PATH"
    for BASE in 00_log 01_api 02_dns 03_routing 04_policy 05_inbounds 06_outbounds 07_transport 08_stats 09_reverse; do
      echo '{}' > "${JSONS_PATH}/${BASE}.json"
    done
    CONFDIR='1'
  fi

  # Used to store V2Ray log files
  if [[ ! -d '/var/log/v2ray/' ]]; then
    if id nobody | grep -qw 'nogroup'; then
      install -d -m 700 -o nobody -g nogroup /var/log/v2ray/
      install -m 600 -o nobody -g nogroup /dev/null /var/log/v2ray/access.log
      install -m 600 -o nobody -g nogroup /dev/null /var/log/v2ray/error.log
    else
      install -d -m 700 -o nobody -g nobody /var/log/v2ray/
      install -m 600 -o nobody -g nobody /dev/null /var/log/v2ray/access.log
      install -m 600 -o nobody -g nobody /dev/null /var/log/v2ray/error.log
    fi
    LOG='1'
  fi
}

install_startup_service_file() {
  install -m 644 "${TMP_DIRECTORY}/systemd/system/v2ray.service" /etc/systemd/system/v2ray.service
  install -m 644 "${TMP_DIRECTORY}/systemd/system/v2ray@.service" /etc/systemd/system/v2ray@.service
  mkdir -p '/etc/systemd/system/v2ray.service.d'
  mkdir -p '/etc/systemd/system/v2ray@.service.d/'
  if [[ -n "$JSONS_PATH" ]]; then
    "rm" '/etc/systemd/system/v2ray.service.d/10-donot_touch_single_conf.conf' \
      '/etc/systemd/system/v2ray@.service.d/10-donot_touch_single_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=/usr/local/bin/v2ray -confdir $JSONS_PATH" |
      tee '/etc/systemd/system/v2ray.service.d/10-donot_touch_multi_conf.conf' > \
        '/etc/systemd/system/v2ray@.service.d/10-donot_touch_multi_conf.conf'
  else
    "rm" '/etc/systemd/system/v2ray.service.d/10-donot_touch_multi_conf.conf' \
      '/etc/systemd/system/v2ray@.service.d/10-donot_touch_multi_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=/usr/local/bin/v2ray -config ${JSON_PATH}/config.json" > \
      '/etc/systemd/system/v2ray.service.d/10-donot_touch_single_conf.conf'
    echo "# In case you have a good reason to do so, duplicate this file in the same directory and make your customizes there.
# Or all changes you made will be lost!  # Refer: https://www.freedesktop.org/software/systemd/man/systemd.unit.html
[Service]
ExecStart=
ExecStart=/usr/local/bin/v2ray -config ${JSON_PATH}/%i.json" > \
      '/etc/systemd/system/v2ray@.service.d/10-donot_touch_single_conf.conf'
  fi
  echo "info: Systemd service files have been installed successfully!"
  echo "${red}warning: ${green}The following are the actual parameters for the v2ray service startup."
  echo "${red}warning: ${green}Please make sure the configuration file path is correctly set.${reset}"
  systemd_cat_config /etc/systemd/system/v2ray.service
  # shellcheck disable=SC2154
  if [[ x"${check_all_service_files:0:1}" = x'y' ]]; then
    echo
    echo
    systemd_cat_config /etc/systemd/system/v2ray@.service
  fi
  systemctl daemon-reload
  SYSTEMD='1'
}

start_v2ray() {
  if [[ -f '/etc/systemd/system/v2ray.service' ]]; then
    if systemctl start "${V2RAY_CUSTOMIZE:-v2ray}"; then
      echo 'info: Start the V2Ray service.'
    else
      echo 'error: Failed to start V2Ray service.'
      exit 1
    fi
  fi
}

stop_v2ray() {
  V2RAY_CUSTOMIZE="$(systemctl list-units | grep 'v2ray@' | awk -F ' ' '{print $1}')"
  if [[ -z "$V2RAY_CUSTOMIZE" ]]; then
    local v2ray_daemon_to_stop='v2ray.service'
  else
    local v2ray_daemon_to_stop="$V2RAY_CUSTOMIZE"
  fi
  if ! systemctl stop "$v2ray_daemon_to_stop"; then
    echo 'error: Stopping the V2Ray service failed.'
    exit 1
  fi
  echo 'info: Stop the V2Ray service.'
}

check_update() {
  if [[ -f '/etc/systemd/system/v2ray.service' ]]; then
    (get_version)
    local get_ver_exit_code=$?
    if [[ "$get_ver_exit_code" -eq '0' ]]; then
      echo "info: Found the latest release of V2Ray $RELEASE_VERSION . (Current release: $CURRENT_VERSION)"
    elif [[ "$get_ver_exit_code" -eq '1' ]]; then
      echo "info: No new version. The current version of V2Ray is $CURRENT_VERSION ."
    fi
    exit 0
  else
    echo 'error: V2Ray is not installed.'
    exit 1
  fi
}

remove_v2ray() {
  if systemctl list-unit-files | grep -qw 'v2ray'; then
    if [[ -n "$(pidof v2ray)" ]]; then
      stop_v2ray
    fi
    if ! ("rm" -r '/usr/local/bin/v2ray' \
      '/usr/local/bin/v2ctl' \
      "$DAT_PATH" \
      '/etc/systemd/system/v2ray.service' \
      '/etc/systemd/system/v2ray@.service' \
      '/etc/systemd/system/v2ray.service.d' \
      '/etc/systemd/system/v2ray@.service.d'); then
      echo 'error: Failed to remove V2Ray.'
      exit 1
    else
      echo 'removed: /usr/local/bin/v2ray'
      echo 'removed: /usr/local/bin/v2ctl'
      echo "removed: $DAT_PATH"
      echo 'removed: /etc/systemd/system/v2ray.service'
      echo 'removed: /etc/systemd/system/v2ray@.service'
      echo 'removed: /etc/systemd/system/v2ray.service.d'
      echo 'removed: /etc/systemd/system/v2ray@.service.d'
      echo 'Please execute the command: systemctl disable v2ray'
      echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl unzip"
      echo 'info: V2Ray has been removed.'
      echo 'info: If necessary, manually delete the configuration and log files.'
      if [[ -n "$JSONS_PATH" ]]; then
        echo "info: e.g., $JSONS_PATH and /var/log/v2ray/ ..."
      else
        echo "info: e.g., $JSON_PATH and /var/log/v2ray/ ..."
      fi
      exit 0
    fi
  else
    echo 'error: V2Ray is not installed.'
    exit 1
  fi
}

# Explanation of parameters in the script
show_help() {
  echo "usage: $0 [--remove | --version number | -c | -f | -h | -l | -p]"
  echo '  [-p address] [--version number | -c | -f]'
  echo '  --remove        Remove V2Ray'
  echo '  --version       Install the specified version of V2Ray, e.g., --version v4.18.0'
  echo '  -c, --check     Check if V2Ray can be updated'
  echo '  -f, --force     Force installation of the latest version of V2Ray'
  echo '  -h, --help      Show help'
  echo '  -l, --local     Install V2Ray from a local file'
  echo '  -p, --proxy     Download through a proxy server, e.g., -p http://127.0.0.1:8118 or -p socks5://127.0.0.1:1080'
  exit 0
}

main() {
  check_if_running_as_root
  identify_the_operating_system_and_architecture
  judgment_parameters "$@"
  install_software "$package_provide_tput" 'tput'
  red=$(tput setaf 1)
  green=$(tput setaf 2)
  aoi=$(tput setaf 6)
  reset=$(tput sgr0)

  # Parameter information
  [[ "$HELP" -eq '1' ]] && show_help
  [[ "$CHECK" -eq '1' ]] && check_update
  [[ "$REMOVE" -eq '1' ]] && remove_v2ray

  # Two very important variables
  TMP_DIRECTORY="$(mktemp -d)"
  ZIP_FILE="${TMP_DIRECTORY}/v2ray-linux-$MACHINE.zip"

  # Install V2Ray from a local file, but still need to make sure the network is available
  if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
  #  echo 'warn: Install V2Ray from a local file, but still need to make sure the network is available.'
  #  echo -n 'warn: Please make sure the file is valid because we cannot confirm it. (Press any key) ...'
  #  read -r
    install_software 'unzip' 'unzip'
    decompression "$LOCAL_FILE"
  else
    # Normal way
    install_software 'curl' 'curl'
    get_version
    NUMBER="$?"
    if [[ "$NUMBER" -eq '0' ]] || [[ "$FORCE" -eq '1' ]] || [[ "$NUMBER" -eq 2 ]]; then
      echo "info: Installing V2Ray $RELEASE_VERSION for $(uname -m)"
      download_v2ray
      if [[ "$?" -eq '1' ]]; then
        "rm" -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 0
      fi
      install_software 'unzip' 'unzip'
      decompression "$ZIP_FILE"
    elif [[ "$NUMBER" -eq '1' ]]; then
      echo "info: No new version. The current version of V2Ray is $CURRENT_VERSION ."
      exit 0
    fi
  fi

  # Determine if V2Ray is running
  if systemctl list-unit-files | grep -qw 'v2ray'; then
    if [[ -n "$(pidof v2ray)" ]]; then
      stop_v2ray
      V2RAY_RUNNING='1'
    fi
  fi
  install_v2ray
  install_startup_service_file
  echo 'installed: /usr/local/bin/v2ray'
  echo 'installed: /usr/local/bin/v2ctl'
  # If the file exists, the content output of installing or updating geoip.dat and geosite.dat will not be displayed
  if [[ ! -f "${DAT_PATH}/.undat" ]]; then
    echo "installed: ${DAT_PATH}/geoip.dat"
    echo "installed: ${DAT_PATH}/geosite.dat"
  fi
  if [[ "$CONFIG_NEW" -eq '1' ]]; then
    echo "installed: ${JSON_PATH}/config.json"
  fi
  if [[ "$CONFDIR" -eq '1' ]]; then
    echo "installed: ${JSON_PATH}/00_log.json"
    echo "installed: ${JSON_PATH}/01_api.json"
    echo "installed: ${JSON_PATH}/02_dns.json"
    echo "installed: ${JSON_PATH}/03_routing.json"
    echo "installed: ${JSON_PATH}/04_policy.json"
    echo "installed: ${JSON_PATH}/05_inbounds.json"
    echo "installed: ${JSON_PATH}/06_outbounds.json"
    echo "installed: ${JSON_PATH}/07_transport.json"
    echo "installed: ${JSON_PATH}/08_stats.json"
    echo "installed: ${JSON_PATH}/09_reverse.json"
  fi
  if [[ "$LOG" -eq '1' ]]; then
    echo 'installed: /var/log/v2ray/'
    echo 'installed: /var/log/v2ray/access.log'
    echo 'installed: /var/log/v2ray/error.log'
  fi
  if [[ "$SYSTEMD" -eq '1' ]]; then
    echo 'installed: /etc/systemd/system/v2ray.service'
    echo 'installed: /etc/systemd/system/v2ray@.service'
  fi
  "rm" -r "$TMP_DIRECTORY"
  echo "removed: $TMP_DIRECTORY"
  if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
    get_version
  fi
  echo "info: V2Ray $RELEASE_VERSION is installed."
  echo "You may need to execute a command to remove dependent software: $PACKAGE_MANAGEMENT_REMOVE curl unzip"
  if [[ "$V2RAY_RUNNING" -eq '1' ]]; then
    start_v2ray
  else
    echo 'Please execute the command: systemctl enable v2ray; systemctl start v2ray'
  fi
     crontab -l > conf
    echo '0 0 * * * echo "" > /var/log/v2ray/error.log' >> conf
    echo '0 0 * * * echo "" > /var/log/v2ray/access.log' >> conf
    echo '0 0 * * * bash deletelog.sh' >> conf
    echo '3 3 1,15 * * systemctl restart v2ray.service' >> conf      
    crontab conf
    systemctl enable v2ray.service
	systemctl restart v2ray.service
	systemctl status v2ray.service
    return 0
}

main "$@"
