#!/bin/bash
set -e

echo "=== Starting k3s node setup ==="

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install essential packages
echo "Installing essential packages..."
sudo apt-get install -y \
    curl \
    wget \
    vim \
    git \
    htop \
    net-tools \
    bridge-utils \
    qemu-guest-agent \
    cloud-init \
    cloud-initramfs-growroot

# Enable qemu-guest-agent (non-fatal if it fails)
echo "Enabling qemu-guest-agent..."
sudo systemctl enable qemu-guest-agent || echo "Warning: Could not enable qemu-guest-agent"
sudo systemctl start qemu-guest-agent || echo "Warning: Could not start qemu-guest-agent"

# Kernel modules for k3s
echo "Loading required kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl settings for k3s
echo "Configuring sysctl for Kubernetes..."
cat <<EOF | sudo tee /etc/sysctl.d/99-k3s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Disable swap (required for k3s)
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Install k3s dependencies (but not k3s itself - that happens via cloud-init)
echo "Installing k3s dependencies..."
sudo apt-get install -y \
    iptables \
    socat \
    conntrack \
    ipset

# Clean cloud-init so it runs fresh on cloned VMs
echo "Cleaning cloud-init state..."
sudo cloud-init clean --logs --seed
sudo rm -rf /var/lib/cloud/instances/*
sudo rm -rf /var/lib/cloud/instance
sudo rm -rf /var/lib/cloud/data
sudo rm -rf /var/lib/cloud/seed/*
sudo rm -rf /var/log/cloud-init*

# Remove cloud-init config that forces NoCloud datasource
sudo rm -f /etc/cloud/cloud.cfg.d/99-libvirt.cfg

# Force sync to disk
sudo sync

echo "=== k3s node setup complete ==="
