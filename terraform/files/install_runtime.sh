#!/bin/bash
# Script to install Kubernetes 1.28.2 on Ubuntu 24.04

set -eux

# Print the script file name
echo "==> Running $0"

KUBE_CORE_VERSION="1.32"
KUBE_VERSION="1.32.3"
CRICTL_VERSION="v1.32.0"
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
CLI_ARCH=arm64

# Update and install prerequisites
apt-get update
apt-get install -y apt-transport-https ca-certificates curl bash-completion binutils vim net-tools iputils-arping

# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_CORE_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_CORE_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Update apt package index
apt-get update

# Install containerd
apt-get install -y containerd.io

# Install crictl
curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-arm64.tar.gz --output crictl.tar.gz
tar zxvf crictl.tar.gz -C /usr/local/bin
rm -f crictl.tar.gz

# Configure crictl to use containerd by default
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Configure containerd
mkdir -p /etc/containerd
containerd config dump > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
# (Optional)
# Specifying the sandbox image as “registry.k8s.io/pause:3.10” is necessary because kubeadm 1.31.2 requires this specific version.
# The default config.toml in containerd points to version 3.8, which could lead to compatibility issues during cluster initialization.
sed -i 's#sandbox_image = "registry.k8s.io/pause:3.8"#sandbox_image = "registry.k8s.io/pause:3.10"#g' /etc/containerd/config.toml
systemctl daemon-reload
systemctl enable containerd.service
systemctl restart containerd.service

# Verify installations
echo "==> Verifying containerd and crictl installations"
crictl --version
containerd --version

# Install specific Kubernetes version
apt-get install -y kubelet=${KUBE_VERSION}-1.1 kubeadm=${KUBE_VERSION}-1.1 kubectl=${KUBE_VERSION}-1.1

# Hold packages to prevent automatic updates
apt-mark hold kubelet kubeadm kubectl

# Create directory for kubeadm config
mkdir -p /etc/kubernetes

# Create directory for kubectl config
mkdir -p /root/.kube

# Install Cilium
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm -f cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Install bash completion
echo 'source /usr/share/bash-completion/bash_completion'>>/root/.bashrc
echo 'source <(kubectl completion bash)' >> /root/.bashrc
echo 'alias k=kubectl' >> /root/.bashrc
echo 'complete -F __start_kubectl k' >> /root/.bashrc
echo 'source /usr/share/bash-completion/bash_completion'>>/home/ubuntu/.bashrc
echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
echo 'complete -F __start_kubectl k' >> /home/ubuntu/.bashrc

# Install Helm
curl -Lo helm.tar.gz https://get.helm.sh/helm-v3.17.3-linux-arm64.tar.gz
tar -zxvf helm.tar.gz
mv linux-arm64/helm /usr/local/bin/helm
rm -rf linux-arm64
rm -f helm.tar.gz
