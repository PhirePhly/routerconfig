#!/bin/bash
# Kenneth Finnegan, 2014
#
# Router Installation script
# This script completely configures a vanilla Ubuntu install as a router

# CONFIG VALUES - Change these for your local network preference
# Bandwidth values in kbits per second
HOSTURL="`hostname -f`"
FIREWALLSH="/usr/local/sbin/firewall-$HOSTURL.sh"

LANDOMAIN="lan.thelifeofkenneth.com"

UPLINKIF="em1"
UPLINKBW="100"
DOWNLINKIF="ifb0"
DOWNLINKBW="100"

NETID="44"
# The entire subnet must be a /8, /16, or /24 for the local rDNS
ENTIRESUBNET="10.$NETID.0.0/16"
SECURESUBNET="10.$NETID.0.0/21"
GUESTSUBNET="10.$NETID.8.0/21"

LANIP="10.$NETID.1.1"
LANNET="10.$NETID.1.0/24"
LANIF="em0"
LANDHCP="10.$NETID.1.100,10.$NETID.1.199,24h"

WIFIIP="10.$NETID.2.1"
WIFINET="10.$NETID.2.0/24"
WIFIIF="$LANIF.2"
WIFIDHCP="10.$NETID.2.100,10.$NETID.2.199,24h"

WIFI5IP="10.$NETID.3.1"
WIFI5NET="10.$NETID.3.0/24"
WIFI5IF="$LANIF.3"
WIFI5DHCP="10.$NETID.3.100,10.$NETID.3.199,24h"

WIFIGUESTIP="10.$NETID.8.1"
WIFIGUESTNET="10.$NETID.8.0/24"
WIFIGUESTIF="$LANIF.8"
WIFIGUESTDHCP="10.$NETID.8.100,10.$NETID.8.199,24h"

WIFIGUEST5IP="10.$NETID.9.1"
WIFIGUEST5NET="10.$NETID.9.0/24"
WIFIGUEST5IF="$LANIF.9"
WIFIGUEST5DHCP="10.$NETID.9.100,10.$NETID.9.199,24h"

MESHIP="10.$NETID.10.1"
MESHIF="wlan0"
MESHSSID="KWF-mesh"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

apt-get update
apt-get install -y apache2 aptitude atop avahi-daemon avahi-utils \
	bridge-utils build-essential dnsmasq dstat iperf \
	lm-sensors minicom mutt nmap ntp pimd postfix \
	samba screen snmp snmp-mibs-downloader snmpd squid3 ssh \
	vim vlan 

# HAVEN'T GOTTEN WORKING YET: miniupnpd miniupnpc minissdpd

# Prevent GRUB from hanging on a bad shutdown
grep -q "GRUB_RECORDFAIL_TIMEOUT" /etc/default/grub ||
	echo "GRUB_RECORDFAIL_TIMEOUT=5" >>/etc/default/grub
update-grub

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
	up	$FIREWALLSH

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

auto $MESHIF
iface $MESHIF inet static
	address $MESHIP
	netmask 255.255.255.0
	wireless-channel 11
	wireless-essid $MESHSSID
	wireless-mode ad-hoc

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
statistics loopstats clockstats
filegen loopstats file loopstats type day enable
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


# Configure iptables firewall and forwarding

cat <<EOF >/etc/sysctl.d/60-enable-ip-forwarding.conf
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF

cat <<EOF >$FIREWALLSH
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
# Flush everything
iptables -F -t nat
iptables -F -t mangle
iptables -F -t filter
iptables -X -t nat
iptables -X -t mangle
iptables -X -t filter

# NAT rule for IPv4
iptables -t nat -A POSTROUTING -s $ENTIRESUBNET -o $UPLINKIF -j MASQUERADE

# Mangle rules for transparent proxy
iptables -t nat -A PREROUTING -s $ENTIRESUBNET -p tcp -m tcp --dport 80 -j DNAT --to-destination $LANIP:3127
iptables -t nat -A PREROUTING -s $ENTIRESUBNET -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 3127

# Port forwards for internal hosts

# Uplink exceptions and block
iptables -A INPUT -i $UPLINKIF -m state --state ESTABLISHED,RELATED -j ACCEPT
# Allow SSH
iptables -A INPUT -i $UPLINKIF -p tcp --dport 22 -j ACCEPT
# Allow SMTP
iptables -A INPUT -i $UPLINKIF -p tcp --dport 25 -j ACCEPT
# Allow DNS
iptables -A INPUT -i $UPLINKIF -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -i $UPLINKIF -p udp --dport 53 -j ACCEPT
# Allow HTTP
iptables -A INPUT -i $UPLINKIF -p tcp --dport 80 -j ACCEPT
# Allow NTP
iptables -A INPUT -i $UPLINKIF -p udp --dport 123 -j ACCEPT

iptables -A INPUT -i $UPLINKIF -p tcp -j DROP
iptables -A INPUT -i $UPLINKIF -p udp -j DROP


# Allow exceptions from DMZ
iptables -A FORWARD -s $GUESTSUBNET -d $SECURESUBNET -m state \
			--state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s $GUESTSUBNET -d $SECURESUBNET -p icmp -j ACCEPT
iptables -A FORWARD -s $GUESTSUBNET -d $SECURESUBNET -p tcp --dport 22 -j ACCEPT

iptables -A FORWARD -s $GUESTSUBNET -d $SECURESUBNET -j DROP


# QoS Upload Enforcement
#iptables -t mangle -N QOS_OUT
#iptables -t mangle -A POSTROUTING -o $UPLINK -j QOS_OUT

# QoS Download Enforcement
#modprobe ifb
#ifconfig $DOWNLINKIF up

EOF

chmod +x $FIREWALLSH


# Config DNSMASQ for DNS and DHCP services

if [ -a /etc/dnsmasq.conf ]; then
	mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
fi

cat <<EOF >/etc/dnsmasq.conf
conf-dir=/etc/dnsmasq.d

dhcp-authoritative
dhcp-leasefile=/run/dhcp.lease
domain-needed
localise-queries
read-ethers
expand-hosts
enable-ra

# Serve locally pointed NTP
dhcp-option=option:ntp-server,0.0.0.0

domain=$LANDOMAIN,$ENTIRESUBNET,local

address=/gw.$LANDOMAIN/$LANIP

# Google DNS servers
server=8.8.8.8
server=8.8.4.4

#
# CONFIGURE INTERFACES
#
auth-server=$LANDOMAIN,$UPLINKIF
interface-name=$LANDOMAIN,$UPLINKIF
auth-zone=$LANDOMAIN

interface=$LANIF
dhcp-range=$LANDHCP
#dhcp-range=1234::,ra-stateless,ra-names
# OR dhcp-range=1234::,slaac,ra-names

interface=$WIFIIF
dhcp-range=$WIFIDHCP

interface=$WIFI5IF
dhcp-range=$WIFI5DHCP

interface=$WIFIGUESTIF
dhcp-range=$WIFIGUESTDHCP

interface=$WIFIGUEST5IF
dhcp-range=$WIFIGUEST5DHCP
EOF

cat <<EOF >/etc/dnsmasq.d/tftp.conf
enable-tftp
tftp-root=/home/tftp
dhcp-boot=trusty-x64/pxelinux.0
EOF


# Configure squid3 proxy for 3128 and 3127 transparent

# Configure OLSR for wlan0 interface

