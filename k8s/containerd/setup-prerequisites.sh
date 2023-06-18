#!/bin/bash
# Prerequisites for k8s nodes.

set -euxo pipefail

# Variable Declaration
KUBERNETES_VERSION="1.27.2-00"

# disable swap
sudo swapoff -a

# keeps the swaf off during reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
sudo apt-get update -y

VERSION="$(echo ${KUBERNETES_VERSION} | grep -oE '[0-9]+\.[0-9]+')"

# Forwarding IPv4 and letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Array of system variables to check
variables=("net.bridge.bridge-nf-call-iptables" "net.bridge.bridge-nf-call-ip6tables" "net.ipv4.ip_forward")

# Iterate over each variable and check its value
for var in "${variables[@]}"; do
  value=$(sysctl -n "$var")
  if [[ "$value" == "1" ]]; then
    echo "$var is set to 1"
  else
    echo "$var is not set to 1"
  fi
done

# Installing containerd
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install containerd.io

# Clear the contents of the config.toml file
sudo bash -c 'echo -n > /etc/containerd/config.toml'

# Add the new configuration to use Systemd for Cgroup
sudo bash -c 'echo "[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc]" >> /etc/containerd/config.toml'
sudo bash -c 'echo "  [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]" >> /etc/containerd/config.toml'
sudo bash -c 'echo "    SystemdCgroup = true" >> /etc/containerd/config.toml'

echo "Configuration added to /etc/containerd/config.toml"

# Restart containerd
sudo systemctl restart containerd

# Installing kubeadm
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
sudo apt-mark hold kubelet kubeadm kubectl

# sudo apt-get install -y jq

# local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
# sudo cat > /etc/default/kubelet << EOF
# KUBELET_EXTRA_ARGS=--node-ip=$local_ip
# EOF
