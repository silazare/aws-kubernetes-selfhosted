#!/bin/bash

set -eux

# Print the script file name
echo "==> Running $0"

hostnamectl set-hostname "${node_name}"

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
# OverlayFS support
modprobe overlay
# Filtering traffic between network bridges
modprobe br_netfilter
echo br_netfilter > /etc/modules-load.d/br_netfilter.conf
systemctl restart systemd-modules-load.service

# Create sysctl config file for Kubernetes
# 1) Enable filtering traffic thru iptables chains for bridges IPv4
# 2) Enable filtering traffic thru iptables chains for bridges IPv6
# 3) Forward packets between interfaces/nodes
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

# Apply sysctl parameters without reboot
sysctl --system

# Verify the settings
echo "==> Verifying sysctl settings"
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
