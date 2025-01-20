#!/bin/bash

set -eux

# Print the script file name
echo "==> Running $0"

hostnamectl set-hostname haproxy-lb-0

apt-get update
apt-get install -y haproxy
