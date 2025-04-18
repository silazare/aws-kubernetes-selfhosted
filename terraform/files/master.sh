#!/bin/bash
# Script to prepare Kubeadm bootstrap script

set -eux

# Print the script file name
echo "==> Running $0"

# Global variables
k8s_version="v1.32.3"
pod_network_cidr="100.64.0.0/16"
svc_network_cidr="100.128.0.0/16"

# IMDSv2 Metadata variables
metadata_url="http://169.254.169.254/latest"
token_ttl=180
token=$(curl -s -H "X-aws-ec2-metadata-token-ttl-seconds: ${token_ttl}" -X PUT "${metadata_url}/api/token")
local_ipv4=$(curl -s -H "X-aws-ec2-metadata-token: ${token}" "${metadata_url}/meta-data/local-ipv4")
public_ipv4=$(curl -s -H "X-aws-ec2-metadata-token: ${token}" "${metadata_url}/meta-data/public-ipv4")

# Put kubeadm config
# !!!
# Add --pod-network-cidr "${pod_network_cidr}" \ to command if you want to use Cilium IPAM mode kubernetes
# Keep as it is if you want to use Cilium IPAM mode cluster-pool
cat <<EOF > /root/bootstrap-master.sh
kubeadm init \
    --kubernetes-version "${k8s_version}" \
    --service-cidr "${svc_network_cidr}" \
    --apiserver-cert-extra-sans=localhost,127.0.0.1,${local_ipv4},${public_ipv4} \
    --skip-phases=addon/kube-proxy \
    --upload-certs \
    -v=5
EOF

chmod 0755 /root/bootstrap-master.sh
