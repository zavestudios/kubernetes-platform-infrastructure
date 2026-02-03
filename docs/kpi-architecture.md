# kubernetes-platform-infrastructure Architecture

**Production-grade k3s cluster infrastructure with automated deployment and multi-environment portability.**

This document covers the complete technical architecture of the kpi infrastructure, including deployment patterns, network topology, authentication flows, and operational procedures.

---

## Overview

kubernetes-platform-infrastructure (kpi) provides Infrastructure as Code to deploy a 3-node k3s cluster on KVM/libvirt virtualization. The infrastructure serves as the foundation for the ZaveStudios multi-tenant platform, hosting multiple tenant applications with isolated resources.

**Key Characteristics:**
- Automated deployment via Terraform + Packer + cloud-init
- ~5 minute deployment time from scratch
- Static IP networking for stability
- Pinned k3s versions for reproducibility
- Multi-environment design (sandbox + AWS-ready)

**Current Deployment: Sandbox Environment**
- Runs on spare compute capacity (ZaveLab hardware)
- $0/month operational cost
- Production-grade automation and patterns
- AWS deployment capability maintained via Terraform

---

## Cluster Architecture

### Node Topology

**3-node cluster composition:**
- 1x Control Plane: `k3s-cp-01` @ 192.168.122.10
- 2x Worker Nodes: `k3s-worker-01` @ 192.168.122.11, `k3s-worker-02` @ 192.168.122.12

**Node specifications:**
- 6 vCPUs per node
- 10GB RAM per node  
- 80GB disk per node
- Ubuntu 24.04 LTS
- containerd runtime
- k3s version: v1.34.3+k3s1 (pinned)

### Network Architecture

**Physical Topology:**
```
Home/Office Network (192.168.1.0/24)
    ├─ Router (192.168.1.1) - Gateway & DHCP
    ├─ Laptop (192.168.1.x) - Management station
    └─ Hypervisor Host (192.168.1.y) - KVM/libvirt host
        └─ br0 (bridge to physical NIC)
            └─ libvirt "default" network (192.168.122.0/24)
                ├─ k3s-cp-01 (192.168.122.10) - static IP
                ├─ k3s-worker-01 (192.168.122.11) - static IP
                └─ k3s-worker-02 (192.168.122.12) - static IP
```

**Network configuration:**
- VMs use libvirt "default" network (192.168.122.0/24)
- Static IPs assigned via cloud-init network_config (not DHCP)
- Gateway: 192.168.122.1
- DNS: 8.8.8.8, 1.1.1.1
- k3s CNI: flannel (VXLAN overlay on port 8472/UDP)

**Why static IPs:**
DHCP with MAC reservations introduced instability - occasional lease failures or IP changes. Static IPs via cloud-init eliminate this entire class of problems. IP addresses are assigned before any services start, with no lease negotiation or timing dependencies.

### Storage Architecture

**Base image storage:**
- Location: `/home/<user>/libvirt_images/` on hypervisor host
- Pool name: `libvirt_images` (libvirt storage pool)
- Base image: `k3s-node-ubuntu-24.04.qcow2` (built by Packer)
- VM disks: CoW clones of base image (thin provisioned)

**Cluster storage:**
- Local path provisioner (included with k3s)
- Dynamic PV provisioning on each node
- Future: NFS for shared storage across nodes

---

## Deployment Architecture

### Infrastructure Stack

**Layer 1: Base Image (Packer)**
- Ubuntu 24.04 LTS minimal server
- cloud-init pre-installed and configured
- Hypervisor tools (qemu-guest-agent)
- Network utilities (curl, wget, ssh)
- Clean state (no machine-id, no cloud-init artifacts)

**Layer 2: VM Provisioning (Terraform + libvirt provider)**
- Provisions 3 VMs from base image
- Injects cloud-init user_data and network_config per node
- Configures static IPs, hostnames, SSH keys
- Connects to libvirt via SSH (remote management from laptop)

**Layer 3: k3s Installation (cloud-init)**
- Validates network connectivity and DNS before installation
- Downloads and installs pinned k3s version (v1.34.3+k3s1)
- Control plane: Initializes cluster with `k3s server`
- Workers: Join cluster with `k3s agent` + control plane token
- Waits for cluster readiness before marking complete

### Deployment Workflow

**Standard deployment from laptop:**
```bash
# 1. Build base image (one-time, on hypervisor host)
cd packer/k3s-node
packer build .

# 2. Deploy cluster (from laptop via containerized Terraform)
cd terraform-libvirt
docker compose run --rm terraform apply

# 3. Wait ~5 minutes for cloud-init to complete

# 4. Verify cluster operational
ssh ubuntu@192.168.122.10 'sudo k3s kubectl get nodes -o wide'
```

**Deployment timeline:**
- VM boot: ~30 seconds per node
- cloud-init network validation: ~15 seconds
- k3s download and install: ~2-3 minutes
- Cluster formation: ~1 minute
- **Total: ~5 minutes to operational cluster**

**Rebuild workflow:**
```bash
terraform destroy  # Remove all VMs
terraform apply    # Recreate identical cluster
# Another 5 minutes, exact same configuration
```

### Key Design Decisions

**Pinned k3s Version (v1.34.3+k3s1):**
- Decision: Use explicit version, not "stable" channel
- Rationale: Reproducible deployments, controlled upgrades, easier troubleshooting
- Trade-off: Manual version updates vs automatic latest

**Network Validation Before k3s Install:**
- Decision: Validate network interface and DNS resolution before k3s installation
- Rationale: Prevents timing failures in certificate generation and API server binding
- Cost: 10-15 seconds added to deployment time
- Implementation: Loop waiting for interface up + DNS working

**Clean Base Images:**
- Decision: Remove all machine-specific state from Packer images
- Rationale: Prevents MAC address conflicts, cloud-init state issues
- Implementation: Cleanup script removes machine-id, cloud-init logs/state, netplan configs
- Result: Each VM gets fresh identifiers and clean cloud-init execution

---

## Connection Architecture

### Management Connections

**Laptop → Hypervisor Host (SSH):**
- Purpose: Terraform libvirt provider connects to hypervisor
- Protocol: SSH tunnel (qemu+ssh://)
- Authentication: SSH key (~/.ssh/id_rsa)
- User: `<user>`
- Port: 22

**Laptop → VMs (SSH):**
- Purpose: Troubleshooting, initial kubeconfig retrieval
- Protocol: SSH
- Authentication: SSH key (injected by Terraform via cloud-init)
- User: ubuntu
- Ports: 22

**Laptop → k3s API (kubectl):**
- Purpose: Normal cluster management
- Protocol: HTTPS with mutual TLS
- Authentication: kubeconfig with client certificates
- Port: 6443
- Endpoint: https://192.168.122.10:6443

### Cluster Internal Connections

**k3s control plane ↔ worker nodes:**
- 6443/TCP: Kubernetes API server
- 10250/TCP: kubelet API
- 8472/UDP: flannel VXLAN overlay
- Authentication: Node certificates + cluster token

**Pod-to-pod networking:**
- flannel CNI manages overlay network
- VXLAN encapsulation for cross-node traffic
- Direct communication within same node

### Authentication Summary

| Connection | Protocol | Auth Method | User/Entity |
|------------|----------|-------------|-------------|
| Laptop → Hypervisor | SSH (port 22) | SSH key | `<user>` |
| Laptop → VMs | SSH (port 22) | SSH key | ubuntu |
| Laptop → k3s API | HTTPS (6443) | kubeconfig mTLS | cluster-admin |
| Terraform → libvirt | SSH tunnel | SSH key | `<user>` |
| VMs ↔ VMs | k3s protocols | k3s certs/tokens | system:nodes |

---

## Hypervisor Configuration

### Prerequisites

**Hardware (hypervisor host):**
- CPU: 18+ cores recommended
- RAM: 32GB minimum (30GB for VMs + 2GB host overhead)
- Disk: 250GB+ free space
- Network: Ethernet connection to home/office network

**Software stack:**
- Ubuntu Server 24.04 LTS
- QEMU/KVM virtualization
- libvirt daemon
- Bridge networking (br0)

### Initial Setup

**Install required packages:**
```bash
sudo apt update
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    openssh-server

# Enable services
sudo systemctl enable libvirtd ssh
sudo systemctl start libvirtd ssh
```

**Configure user permissions:**
```bash
# Add user to required groups
sudo usermod -aG kvm,libvirt $USER

# Log out and back in for changes to take effect
# Verify membership
groups | grep -E 'kvm|libvirt'
```

**Configure libvirt for remote access:**
```bash
# Edit /etc/libvirt/libvirtd.conf
sudo vim /etc/libvirt/libvirtd.conf

# Required settings:
listen_tls = 0
listen_tcp = 0
unix_sock_group = "libvirt"
unix_sock_rw_perms = "0770"

# Restart libvirtd
sudo systemctl restart libvirtd
```

**Create storage pool:**
```bash
# Create storage directory
mkdir -p ~/libvirt_images

# Define pool via virsh
virsh pool-define-as libvirt_images dir - - - - "$HOME/libvirt_images"
virsh pool-build libvirt_images
virsh pool-start libvirt_images
virsh pool-autostart libvirt_images

# Verify
virsh pool-list --all
```

### Remote Access Testing

**From laptop, test libvirt connection:**
```bash
# Test SSH access
ssh <user>@<host-ip> 'hostname'

# Test libvirt via SSH tunnel
virsh -c qemu+ssh://<user>@<host-ip>/system list --all

# Should return empty list (no VMs yet)

# Test pool access
virsh -c qemu+ssh://<user>@<host-ip>/system pool-list

# Should show libvirt_images pool
```

---

## Operational Procedures

### Standard Operations

**Deploy cluster:**
```bash
cd terraform-libvirt
docker compose run --rm terraform apply
# Wait ~5 minutes
```

**Access cluster:**
```bash
# Get kubeconfig
ssh ubuntu@192.168.122.10 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/kpi.yaml

# Update server IP
sed -i 's/127.0.0.1/192.168.122.10/' ~/.kube/kpi.yaml

# Use kubectl
export KUBECONFIG=~/.kube/kpi.yaml
kubectl get nodes -o wide
```

**Destroy cluster:**
```bash
cd terraform-libvirt
docker compose run --rm terraform destroy
# Removes all VMs, keeps base image
```

**Rebuild cluster:**
```bash
terraform destroy && terraform apply
# Complete cluster recreation in ~5 minutes
```

### Troubleshooting

**VM won't start:**
```bash
# Check libvirt logs on host
ssh <user>@<host-ip> 'sudo journalctl -u libvirtd -n 50'

# Check VM console
virsh -c qemu+ssh://<user>@<host-ip>/system console k3s-cp-01
```

**k3s service failed:**
```bash
# SSH to affected node
ssh ubuntu@192.168.122.10

# Check k3s status
sudo systemctl status k3s
# or for worker:
sudo systemctl status k3s-agent

# View logs
sudo journalctl -u k3s -f
```

**Network connectivity issues:**
```bash
# Check VM can reach internet
ssh ubuntu@192.168.122.10 'ping -c 3 8.8.8.8'

# Check DNS resolution
ssh ubuntu@192.168.122.10 'nslookup google.com'

# Check k3s pod networking
kubectl get pods -A -o wide
kubectl logs <pod-name> -n <namespace>
```

**Can't access k3s API:**
```bash
# Verify API server is running
ssh ubuntu@192.168.122.10 'sudo systemctl status k3s'

# Test API endpoint
curl -k https://192.168.122.10:6443/version

# Check kubeconfig server address
grep server: ~/.kube/kpi.yaml
# Should be: https://192.168.122.10:6443
```

### Maintenance

**Update k3s version:**
```bash
# 1. Update version in cloud-init templates
vim terraform-libvirt/cloud-init/k3s-cp.yml.tpl
vim terraform-libvirt/cloud-init/k3s-worker.yml.tpl

# Change: INSTALL_K3S_VERSION=v1.34.3+k3s1
# To: INSTALL_K3S_VERSION=v1.35.0+k3s1

# 2. Destroy and recreate cluster
terraform destroy && terraform apply

# 3. Verify new version
kubectl version
```

**Update base image:**
```bash
# 1. On hypervisor host, rebuild Packer image
cd ~/kubernetes-platform-infrastructure/packer/k3s-node
packer build .

# 2. From laptop, destroy and recreate VMs
cd terraform-libvirt
terraform destroy && terraform apply

# VMs now use new base image
```

---

## Multi-Environment Strategy

### Sandbox Environment (Current)

**Infrastructure:**
- Runs on hypervisor host (spare compute capacity)
- KVM/libvirt virtualization
- Static IPs on local network
- No external dependencies

**Cost:** $0/month

**Use cases:**
- Continuous platform development
- Tenant application hosting
- GitOps testing
- Learning and experimentation

### AWS Environment (Future)

**Infrastructure:**
- EKS cluster (managed control plane)
- EC2 spot instances (worker nodes)
- AWS networking (VPC, subnets, load balancers)
- Same tenant applications and platform services

**Cost:** ~$10-20 per weekend deployment

**Use cases:**
- Technical demonstrations
- Architecture validation
- Cloud-native pattern testing

**Deployment time:** ~20 minutes via Terraform

**Portability approach:**
- Application manifests identical in both environments
- Environment-specific infrastructure via Kustomize overlays
- Same GitOps workflows (Flux + ArgoCD)
- Storage classes and load balancer types differ, apps don't

---

## Security Considerations

### SSH Key Management

**Single keypair strategy:**
- Private key: `~/.ssh/id_rsa` (stays on laptop only)
- Public key: `~/.ssh/id_rsa.pub` (distributed to hypervisor host and VMs)
- Used for: laptop → hypervisor, laptop → VMs, Terraform → libvirt

**Never:**
- Copy private key to VMs or hypervisor host
- Commit private key to git
- Use same key for multiple people

### VM Security

**Access controls:**
- Only SSH key authentication (no passwords)
- Root login disabled
- Single user: `ubuntu` with sudo access
- SSH on port 22 only

**Network isolation:**
- VMs on isolated subnet (192.168.122.0/24)
- No direct external access (requires jump through hypervisor host)
- Future: Cloudflare Tunnel for external access

### Cluster Security

**API access:**
- mTLS certificate authentication required
- RBAC policies enforced
- Default: cluster-admin access via kubeconfig

**Future hardening:**
- Network policies for pod-to-pod traffic
- OPA/Gatekeeper for admission control
- Istio service mesh with mTLS

---

## File Structure Reference

```
kubernetes-platform-infrastructure/
├── terraform-libvirt/
│   ├── main.tf                    # VM definitions, cloud-init resources
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # IP addresses, connection info
│   ├── terraform.tfvars.example   # Example configuration
│   ├── docker-compose.yml         # Containerized Terraform
│   └── cloud-init/
│       ├── k3s-cp.yml.tpl        # Control plane cloud-init
│       ├── k3s-worker.yml.tpl    # Worker cloud-init
│       └── network-config.yml.tpl # Network configuration
├── packer/
│   └── k3s-node/
│       ├── k3s-node.pkr.hcl      # Packer template
│       ├── variables.pkr.hcl      # Packer variables
│       └── scripts/
│           └── setup.sh           # Provisioning + cleanup
├── scripts/
│   ├── cleanup-terraform-state.sh    # Dev: remove from state
│   └── cleanup-libvirt-resources.sh  # Dev: destroy VMs/volumes
└── docs/
    ├── architecture.md            # This document
    └── adrs/                      # Architecture decision records
```

---

## Related Documentation

- [Quick Start Guide](../README.md) - Deployment instructions
- [ADR-003: Flux and ArgoCD Separation](adrs/003-flux-and-argocd-separation.md)
- [ADR-004: Hybrid Sandbox + AWS Architecture](adrs/004-hybrid-sandbox-aws-architecture.md)
- [ZaveStudios Platform Overview](https://github.com/eckslopez/zavestudios)
- [k3s Documentation](https://docs.k3s.io/)
- [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)

---

**Last Updated:** January 28, 2025  
**Environment:** Sandbox (hypervisor host)  
**k3s Version:** v1.34.3+k3s1  
**Cluster Status:** Operational
