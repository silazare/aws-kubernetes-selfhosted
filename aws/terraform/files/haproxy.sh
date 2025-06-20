#!/bin/bash

set -eux

# Print the script file name
echo "==> Running $0"

hostnamectl set-hostname haproxy-lb-0

apt-get update
apt-get install -y haproxy net-tools

# Configure ARP settings for L2 announcements in AWS
cat <<EOF | tee /etc/sysctl.d/99-arp-l2.conf
# Enable proxy ARP to respond to ARP requests for other addresses
net.ipv4.conf.all.proxy_arp = 1
net.ipv4.conf.ens5.proxy_arp = 1

# Set ARP announce mode to 2 (announce on all interfaces)
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.ens5.arp_announce = 2

# Set ARP ignore to 0 (answer requests for IPs on any interface)
net.ipv4.conf.all.arp_ignore = 0
net.ipv4.conf.ens5.arp_ignore = 0
EOF

# Apply sysctl parameters without reboot
sysctl --system
