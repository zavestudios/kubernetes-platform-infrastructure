#cloud-config
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    fs_label: cidata

hostname: ${hostname}
fqdn: ${hostname}.local

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}

# Enable password auth temporarily for debugging
ssh_pwauth: true
chpasswd:
  expire: false
  list:
    - ubuntu:ubuntu

write_files:
  - path: /etc/systemd/system/k3s.service.d/override.conf
    content: |
      [Service]
      Restart=always
      RestartSec=5s

# Configure timezone
timezone: UTC

# System updates
package_update: true
package_upgrade: true

# Additional packages
packages:
  - curl
  - vim
  - htop
  - net-tools

# Install k3s server
runcmd:
  - |
    # Find the primary network interface (not lo)
    echo "Finding primary network interface..."
    PRIMARY_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$PRIMARY_IF" ]; then
      # Fallback: find first non-loopback interface with an IP
      PRIMARY_IF=$(ip -o link show | grep -v "lo:" | head -n1 | awk -F': ' '{print $2}')
    fi
    echo "Using interface: $PRIMARY_IF"
    
    # Wait for network interface to have an IP
    echo "Waiting for network interface to have IP..."
    for i in {1..30}; do
      if ip addr show "$PRIMARY_IF" | grep -q "inet "; then
        echo "Network interface has IP"
        break
      fi
      echo "Attempt $i: No IP yet..."
      sleep 2
    done
    
    # Wait for default route
    echo "Waiting for default route..."
    for i in {1..30}; do
      if ip route | grep -q "default"; then
        echo "Default route exists"
        break
      fi
      echo "Attempt $i: No default route yet..."
      sleep 2
    done
    
    # Wait for DNS resolution (multiple DNS servers)
    echo "Waiting for DNS resolution..."
    for i in {1..60}; do
      if nslookup get.k3s.io 8.8.8.8 &>/dev/null || \
         nslookup get.k3s.io 1.1.1.1 &>/dev/null; then
        echo "DNS resolution working"
        break
      fi
      echo "Attempt $i: DNS not ready..."
      sleep 2
    done
    
    # Final connectivity test to k3s download site
    echo "Testing connectivity to get.k3s.io..."
    if ! curl -sSf -m 10 https://get.k3s.io >/dev/null; then
      echo "ERROR: Cannot reach get.k3s.io - check network connectivity"
      exit 1
    fi
    
    echo "Network is ready, installing k3s..."
    
    # Install k3s server
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="${k3s_version}" \
      K3S_TOKEN="${k3s_token}" \
      sh -s - server \
      --write-kubeconfig-mode 644 \
      --disable=traefik \
      --tls-san=127.0.0.1 \
      --node-name=${hostname}
    
    # Wait for k3s to be ready
    until kubectl get nodes &>/dev/null; do
      echo "Waiting for k3s..."
      sleep 5
    done
    
    echo "k3s control plane ready"

final_message: "k3s control plane node ${hostname} is ready after $UPTIME seconds"