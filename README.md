# masternode-PentaNode-scrip-v1.301
Open the Pentanode Desktop Wallet.

Go to console ( help -> debug window)

**commands: masternode genkey (privekey**
copy it
-Installation for v1.301 on vps

wget -q https://raw.githubusercontent.com/PentaNode/Masternode/master/pentanode.sh

bash pentanode.sh

When prompted to enter your Genkey : past genkey(privekey) on the step **

-Config wallet setup on cold ( wallet on windows or linux, Contain Required coins for masternode

-After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:

-Open the Pentanode Desktop Wallet.

-Go to RECEIVE and create a New Address: MN1

-Send 2500 5000 10000 15000 or 25000 PTN to MN1.

-Wait for 15 confirmations.

-Go to Help -> "Debug Window - Console"

-Type the following command: masternode outputs

-Go to Masternodes tab

-Click Create and fill the details:

-Alias: MN1

-Address: VPS_IP:PORT

-Privkey: Value given during VPS Setup

-TxHash: First value from Step 6

-Output index: Second value from Step 6

-Reward address: leave blank or fill with PTN address of your choice

-Reward %: leave blank or fill with the percentage of your choice

-Click OK to add the masternode

-Click Update

-Click Start (If the wallet is not unlocked then unlock wallet)


**Multiple MN on one VPS:
It is now possible to run multiple Pentanode Master Nodes on the same VPS. Each MN will run under a different user you will choose during installation.

Usage:
For security reasons Pentanode is installed under a normal user, usually pentanode, hence you need to su - pentanode before checking:

PENTAUSER=pentanode #replace pentanode with the MN username you want to check  
su - $PENTAUSER
PentaNoded masternode status  
PentaNoded getinfo
Also, if you want to check/start/stop pentanode daemon for a particular MN, run one of the following commands as root:

PENTAUSER=pentanode  #replace pentanode with the MN username you want to check  
systemctl status $PENTAUSER #To check the service is running

systemctl start $PENTAUSER #To start PentaNoded service 

systemctl stop $PENTAUSER #To stop PentaNoded service

systemctl is-enabled $PENTAUSER #To check PentaNoded service is enabled on boot  

**Wallet re-sync
*If you need to resync the wallet, run the following commands as root:

**PENTAUSER=pentanode  #replace pentanode with the MN username you want to resync

systemctl stop $PENTAUSER

Addnode this line to the file in /home/pentanode/.PentaNode/PentaNode.conf:

addnode=139.99.98.127

addnode=139.99.98.128

addnode=139.99.98.129

addnode=96.43.131.76

addnode=95.79.43.111

addnode=95.31.8.89

addnode=95.31.244.93

systemctl start $PENTAUSER

wallet on VPS resync vs blockchain.

If you have any problems please contact telegram or discord: nh9cvjetkt

Donate if good:

ETH: 0x11a985d42D6fa4CAC941943a63f362c3497FA0Fe

BTC: 1EcpUdLTyeVuxNNePLjaxLuh88Rnphf959

PTN: PoEMmh9VvFitJJS8z1RSEpheuTDE5vTHZX
