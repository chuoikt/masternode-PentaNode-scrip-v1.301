#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="PentaNode.conf"
CONFIG_FOLDER=".PentaNode"
BINARY_FILE="/usr/local/bin/PentaNoded"
PENTA_REPO="https://github.com/PentaNode/Pentanode-wallet.git"
COIN_TGZ='https://github.com/PentaNode/Pentanode-wallet/raw/master/PentaNoded'

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof PentaNoded)" ]; then
  echo -e "${GREEN}\c"
  read -e -p "PentaNoded is already running. Do you want to add another MN? [Y/N]" NEW_PENTA
  echo -e "{NC}"
  clear
else
  NEW_PENTA="new"
fi
}

function prepare_system() {

echo -e "Prepare the system to install Pentanode masternode."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils \
libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pwgen
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw"
 exit 1
fi

clear
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(swapon -s)
if [[ "$PHYMEM" -lt "2" && -z "$SWAP" ]];
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM, creating 2G swap file.${NC}"
    dd if=/dev/zero of=/swapfile bs=1024 count=2M
    chmod 600 /swapfile
    mkswap /swapfile
    swapon -a /swapfile
else
  echo -e "${GREEN}The server running with at least 2G of RAM, or SWAP exists.${NC}"
fi
clear
}

function deploy_binaries() {
  cd $TMP
  wget -q $COIN_TGZ >/dev/null 2>&1
  gunzip PentaNoded.gz >/dev/null 2>&1
  chmod +x PentaNoded >/dev/null 2>&1
  cp PentaNoded /usr/local/bin/ >/dev/null 2>&1
}

function ask_permission() {
 echo -e "${RED}I trust PentaNode Team and want to use binaries compiled on his server.${NC}."
 echo -e "Please type ${RED}YES${NC} if you want to use precompiled binaries, or type anything else to compile them on your server"
 read -e TRUST
}

function ask_firewall() {
 echo -e "${RED}I want to protect this server with a firewall and limit connexion to SSH and Pentanode.${NC}."
 echo -e "Please type ${RED}YES${NC} if you want to enable the firewall, or type anything else to skip"
 read -e UFW
}

function compile_pentanode() {
  echo -e "Clone git repo and compile it. This may take some time. Press a key to continue."
  read -n 1 -s -r -p ""

  git clone $PENTA_REPO $TMP_FOLDER
  cd $TMP_FOLDER/src
  make -f makefile.unix
  compile_error PentaNode
  cp -a PentaNoded $BINARY_FILE
  clear
}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow incomning access on port ${GREEN}$PENTANODEPORT${NC}"
  ufw allow $PENTANODEPORT/tcp comment "Pentanode MN port" >/dev/null
  ufw allow $[PENTANODEPORT+1]/tcp comment "Pentanode RPC port" >/dev/null
  ufw allow ssh >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}

function systemd_pentanode() {
  cat << EOF > /etc/systemd/system/$PENTANODEUSER.service
[Unit]
Description=Pentanode service
After=network.target

[Service]

Type=forking
User=$PENTANODEUSER
Group=$PENTANODEUSER
WorkingDirectory=$PENTANODEHOME
ExecStart=$BINARY_FILE -daemon
ExecStop=$BINARY_FILE stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
  
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $PENTANODEUSER.service
  systemctl enable $PENTANODEUSER.service >/dev/null 2>&1

  if [[ -z $(pidof PentaNoded) ]]; then
    echo -e "${RED}PentaNoded is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo "systemctl start $PENTANODEUSER.service"
    echo "systemctl status $PENTANODEUSER.service"
    echo "less /var/log/syslog"
    exit 1
  fi
}

function ask_port() {
DEFAULTPENTANODEPORT=8557
read -p "PENTANODE Port: " -i $DEFAULTPENTANODEPORT -e PENTANODEPORT
: ${PENTANODEPORT:=$DEFAULTPENTANODEPORT}
}

function ask_user() {
  DEFAULTPENTANODEUSER="pentanode"
  read -p "Pentanode user: " -i $DEFAULTPENTANODEUSER -e PENTANODEUSER
  : ${PENTANODEUSER:=$DEFAULTPENTANODEUSER}

  if [ -z "$(getent passwd $PENTANODEUSER)" ]; then
    useradd -m $PENTANODEUSER
    USERPASS=$(pwgen -s 12 1)
    echo "$PENTANODEUSER:$USERPASS" | chpasswd

    PENTANODEHOME=$(sudo -H -u $PENTANODEUSER bash -c 'echo $HOME')
    DEFAULTPENTANODEFOLDER="$PENTANODEHOME/.PentaNode"
    read -p "Configuration folder: " -i $DEFAULTPENTANODEFOLDER -e PENTANODEFOLDER
    : ${PENTANODEFOLDER:=$DEFAULTPENTANODEFOLDER}
    mkdir -p $PENTANODEFOLDER
    chown -R $PENTANODEUSER: $PENTANODEFOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $PENTANODEPORT ]] || [[ ${PORTS[@]} =~ $[PENTANODEPORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $PENTANODEFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[PENTANODEPORT+1]
listen=1
server=1
daemon=1
port=$PENTANODEPORT
addnode=139.99.98.127
addnode=139.99.98.128
addnode=139.99.98.129
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e PENTANODEKEY
  if [[ -z "$PENTANODEKEY" ]]; then
  sudo -u $PENTANODEUSER /usr/local/bin/PentaNoded -conf=$PENTANODEFOLDER/$CONFIG_FILE -datadir=$PENTANODEFOLDER
  sleep 5
  if [ -z "$(pidof PentaNoded)" ]; then
   echo -e "${RED}PentaNoded server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  PENTANODEKEY=$(sudo -u $PENTANODEUSER $BINARY_FILE -conf=$PENTANODEFOLDER/$CONFIG_FILE -datadir=$PENTANODEFOLDER masternode genkey)
  sudo -u $PENTANODEUSER $BINARY_FILE -conf=$PENTANODEFOLDER/$CONFIG_FILE -datadir=$PENTANODEFOLDER stop
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $PENTANODEFOLDER/$CONFIG_FILE
  NODEIP=$(curl -s4 icanhazip.com)
  cat << EOF >> $PENTANODEFOLDER/$CONFIG_FILE
logtimestamps=1
maxconnections=256
masternode=1
masternodeaddr=$NODEIP:$PENTANODEPORT
masternodeprivkey=$PENTANODEKEY
EOF
  chown -R $PENTANODEUSER: $PENTANODEFOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Pentanode Masternode is up and running as user ${GREEN}$PENTANODEUSER${NC} and it is listening on port ${GREEN}$PENTANODEPORT${NC}."
 echo -e "${GREEN}$PENTANODEUSER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$PENTANODEFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $PENTANODEUSER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $PENTANODEUSER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$PENTANODEPORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$PENTANODEKEY${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  check_port
  create_config
  create_key
  update_config
  ask_firewall
  if [[ "$UFW" == "YES" ]]; then
    enable_firewall
  fi  
  systemd_pentanode
  important_information
}


##### Main #####
clear

checks
if [[ ("$NEW_PENTA" == "y" || "$NEW_PENTA" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_PENTA" == "new" ]]; then
  prepare_system
  ask_permission
  if [[ "$TRUST" == "YES" ]]; then
    deploy_binaries
  else
    compile_pentanode
  fi
  setup_node
else
  echo -e "${GREEN}PentaNoded already running.${NC}"
  exit 0
fi

