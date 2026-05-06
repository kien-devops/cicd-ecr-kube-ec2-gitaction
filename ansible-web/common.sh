#!/bin/bash
set -euxo pipefail

KUBERNETES_VERSION="v1.30"
CRIO_VERSION="v1.30"
KUBERNETES_INSTALL_VERSION="1.30.0-1.1"
NODE_EXPORTER_VERSION="1.8.2"

# Disable swap now and on reboot
sudo swapoff -a

# Comment swap entry in /etc/fstab so it stays off after reboot
sudo sed -i.bak '/\sswap\s/s/^\(.*\)$/#\1/g' /etc/fstab || true

# Basic packages
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common jq cron tar
sudo systemctl enable cron --now || true

# Keep swap disabled after reboot
(crontab -l 2>/dev/null || true; echo "@reboot /sbin/swapoff -a") | crontab -

# Kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl params required by Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Remove containerd to avoid multiple CRI conflicts
sudo apt-get remove -y containerd containerd.io || true
sudo apt-get autoremove -y || true

# Install CRI-O repo key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/addons:/cri-o:/stable:/${CRIO_VERSION}/deb/Release.key" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/${CRIO_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update -y
sudo apt-get install -y cri-o

sudo systemctl daemon-reload
sudo systemctl enable crio --now
sudo systemctl start crio.service

echo "CRI runtime installed successfully"

# Install Kubernetes repo key
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet="${KUBERNETES_INSTALL_VERSION}" kubeadm="${KUBERNETES_INSTALL_VERSION}" kubectl="${KUBERNETES_INSTALL_VERSION}"
sudo apt-mark hold kubelet kubeadm kubectl

# Detect node IP dynamically from eth0 or default interface
DEFAULT_IFACE=$(ip route | awk '/default/ {print $5; exit}')
NODE_IP=$(ip -4 addr show "${DEFAULT_IFACE}" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)

if [ -z "${NODE_IP}" ]; then
  NODE_IP=$(hostname -I | awk '{print $1}')
fi

# Configure kubelet to use CRI-O and detected node IP
sudo mkdir -p /etc/default
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP} --container-runtime-endpoint=unix:///var/run/crio/crio.sock
EOF

sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl restart kubelet

if ! id node_exporter >/dev/null 2>&1; then
  sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter
fi

if [[ ! -x /usr/local/bin/node_exporter ]]; then
  NODE_EXPORTER_ARCH="linux-amd64"
  NODE_EXPORTER_TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.${NODE_EXPORTER_ARCH}.tar.gz"
  NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_TARBALL}"
  TMP_DIR="$(mktemp -d)"

  curl -fsSL "${NODE_EXPORTER_URL}" -o "${TMP_DIR}/${NODE_EXPORTER_TARBALL}"
  tar -xzf "${TMP_DIR}/${NODE_EXPORTER_TARBALL}" -C "${TMP_DIR}"
  sudo install -o node_exporter -g node_exporter -m 0755 \
    "${TMP_DIR}/node_exporter-${NODE_EXPORTER_VERSION}.${NODE_EXPORTER_ARCH}/node_exporter" \
    /usr/local/bin/node_exporter
  rm -rf "${TMP_DIR}"
fi

cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter --now
sudo systemctl restart node_exporter

echo "Kubernetes components installed successfully"
echo "Node Exporter installed successfully on port 9100"
echo "Detected node IP: ${NODE_IP}"
