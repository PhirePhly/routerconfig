#!/bin/bash
# Kenneth Finnegan, 2014
#
# Router Installation script
# This script completely configures a vanilla Ubuntu install as a router

# CONFIG VALUES - Change these for your local network preference
# Bandwidth values in kbits per second
UPLINKIF="em1"
UPLINKBW="100"
DOWNLINKIF="ifb0"
DOWNLINKBW="100"

SECURESUBNET="10.44.0.0/21"
GUESTSUBNET="10.44.8.0/21"

LANIP="10.42.1.1"
LANNET="10.42.1.0/24"
LANIF="em0"

WIFIIP="10.44.2.1"
WIFINET="10.44.2.0/24"
WIFIIF="$LANIF.2"

WIFI5IP="10.44.3.1"
WIFI5NET="10.44.3.0/24"
WIFI5IF="$LANIF.3"

WIFIGUESTIP="10.44.8.1"
WIFIGUESTNET="10.44.8.0/24"
WIFIGUESTIF="$LANIF.8"

WIFIGUEST5IP="10.44.9.1"
WIFIGUEST5NET="10.44.9.0/24"
WIFIGUEST5IF="$LANIF.9"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

apt-get update
apt-get install -y apache2 aptitude atop avahi-daemon avahi-utils \
	bridge-utils build-essential dnsmasq dstat iperf \
	minicom mutt nmap ntp pimd postfix \
	samba screen snmp snmp-mibs-downloader snmpd ssh \
	vim vlan


# Configure network interfaces
if [ -a /etc/network/interfaces ]; then
	mv /etc/network/interfaces /etc/network/interfaces.bak
fi

cat <<EOF >/etc/network/interfaces
auto lo
iface lo inet loopback

# Interior network interfaces
auto $LANIF
iface $LANIF inet static
	address $LANIP
	netmask 255.255.255.0

auto $WIFIIF
iface $WIFIIF inet static
	address $WIFIIP
	netmask 255.255.255.0
	vlan-raw-device $LANIF

auto $WIFI5IF
iface $WIFI5IF inet static
	address $WIFI5IP
	netmask 255.255.255.0
	vlan-raw-device $LANIF

auto $WIFIGUESTIF
iface $WIFIGUESTIF inet static
	address $WIFIGUESTIP
	netmask 255.255.255.0
	vlan-raw-device $LANIF

auto $WIFIGUEST5IF
iface $WIFIGUEST5IF inet static
	address $WIFIGUEST5IP
	netmask 255.255.255.0
	vlan-raw-device $LANIF

# Exterior network interfaces
auto $UPLINKIF
iface $UPLINKIF inet dhcp
EOF


# Configure NTP time server
if [ -a /etc/ntp.conf ]; then
	mv /etc/ntp.conf /etc/ntp.conf.bak
fi

cat <<EOF >/etc/ntp.conf
driftfile /var/lib/ntp/ntp.drift
statsdir /var/log/ntpstats/
statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

server 0.us.pool.ntp.org iburst
server 1.us.pool.ntp.org iburst
server 2.us.pool.ntp.org iburst
server 3.us.pool.ntp.org iburst

restrict -4 default kod notrap nomodify noquery
restrict -6 default kod notrap nomodify noquery
restrict 127.0.0.1
restrict ::1

broadcast 239.192.6.87 ttl 7
disable auth
multicastclient 239.192.6.87 iburst
EOF


