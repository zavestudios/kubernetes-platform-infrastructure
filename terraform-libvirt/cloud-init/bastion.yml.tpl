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
  - jq
  - git

# Install cluster management tools
runcmd:
  - |
    # Wait for network
    echo "Waiting for network..."
    for i in {1..30}; do
      if ip route | grep -q "default"; then
        echo "Network ready"
        break
      fi
      sleep 2
    done

    # Install kubectl (matching k3s version)
    echo "Installing kubectl..."
    K3S_VERSION="${k3s_version}"
    K8S_VERSION=$(echo $K3S_VERSION | sed 's/+k3s.*//')
    curl -LO "https://dl.k8s.io/release/$K8S_VERSION/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/

    # Install k9s
    echo "Installing k9s..."
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -sL https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_amd64.tar.gz | tar xvz -C /tmp
    sudo mv /tmp/k9s /usr/local/bin/

    # Install Flux CLI
    echo "Installing Flux CLI..."
    curl -s https://fluxcd.io/install.sh | sudo bash

    # Install Helm
    echo "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Setup kubeconfig for ubuntu user
    echo "Setting up kubeconfig..."
    mkdir -p /home/ubuntu/.kube

    # Wait for control plane to be ready and fetch kubeconfig
    echo "Waiting for k3s control plane..."
    for i in {1..60}; do
      if ssh -o StrictHostKeyChecking=no -o BatchMode=yes ubuntu@${control_plane_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' 2>/dev/null > /home/ubuntu/.kube/config; then
        # Update server URL to use control plane IP
        sed -i 's/127.0.0.1/${control_plane_ip}/g' /home/ubuntu/.kube/config
        chmod 600 /home/ubuntu/.kube/config
        chown ubuntu:ubuntu /home/ubuntu/.kube/config
        echo "Kubeconfig configured"
        break
      fi
      echo "Attempt $i: Control plane not ready..."
      sleep 10
    done

    # Verify kubectl access
    if sudo -u ubuntu kubectl get nodes &>/dev/null; then
      echo "kubectl access verified"
    else
      echo "Warning: kubectl access not yet available"
    fi

    echo "Bastion setup complete"

final_message: "Bastion host ${hostname} is ready after $UPTIME seconds"
