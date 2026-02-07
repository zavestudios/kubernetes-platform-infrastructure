# kubernetes-platform-infrastructure

**Automated 3-node k3s cluster deployment on KVM/libvirt virtualization.**

Part of the [ZaveStudios multi-tenant platform](https://github.com/zavestudios/zavestudios) - provides the infrastructure layer for hosting multiple tenant applications with isolated resources.

## Quick Start

**First-time setup from laptop** (zero to running cluster in ~11 minutes):

```bash
# 1. Clone repository
git clone https://github.com/zavestudios/kubernetes-platform-infrastructure.git
cd kubernetes-platform-infrastructure

# 2. Build base image on hypervisor (~3.5 minutes)
# SSH to your hypervisor host and run:
cd ~/kubernetes-platform-infrastructure/packer/k3s-node
packer build .

# 3. Configure Terraform variables (laptop)
cd ~/kubernetes-platform-infrastructure/terraform-libvirt
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
# Required: Set ssh_public_key_path = "~/.ssh/id_rsa.pub"

# 4. Initialize Terraform (~3 seconds)
docker compose run --rm terraform init

# 5. Import base volume to Terraform state (~2 seconds)
docker compose run --rm terraform import libvirt_volume.base \
  /home/YOUR_USER/libvirt_images/k3s-node-ubuntu-24.04.qcow2

# 6. Deploy cluster (~7 seconds for VMs)
docker compose run --rm terraform apply

# Wait ~7 minutes for cloud-init to install k3s and bootstrap cluster

# 7. Verify VMs are running
ssh ubuntu@192.168.122.10 echo "VM reachable"
# On first connection, you'll see:
# Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
# Warning: Permanently added '192.168.122.10' (ED25519) to the list of known hosts.
# Password: ubuntu

# 8. Check cloud-init completion
ssh ubuntu@192.168.122.10 'cloud-init status --wait'
# Output when done: status: done

# 9. Verify cluster is operational
ssh ubuntu@192.168.122.10 'sudo k3s kubectl get nodes'
# All 3 nodes should show Ready status

# 10. Setup SSH config (one-time)
# Copy config-templates/ssh-config.example to ~/.ssh/config
# Update <HYPERVISOR_IP> and <YOUR_SSH_KEY> placeholders

# 11. Setup kubectl access from laptop via bastion (~1 second)
./scripts/setup-kubectl-bastion.sh
export KUBECONFIG=~/.kube/kpi.yaml
kubectl get nodes -o wide
```

**Expected output:**
```
NAME            STATUS   ROLES           AGE   VERSION
k3s-cp-01       Ready    control-plane   7m    v1.34.3+k3s1
k3s-worker-01   Ready    <none>          7m    v1.34.3+k3s1
k3s-worker-02   Ready    <none>          7m    v1.34.3+k3s1
```

**Alternative: Use kubectl directly on bastion:**
```bash
ssh kpi-bastion-01
kubectl get nodes  # kubeconfig pre-configured
k9s               # interactive cluster management
```

## What This Provides

- **3-node k3s cluster**: 1 control plane + 2 workers
- **Bastion host**: Dedicated jump box with kubectl, k9s, flux, helm pre-installed
- **Automated deployment**: Terraform + Packer + cloud-init
- **Static networking**: Predictable IPs (192.168.122.10-13)
- **Production patterns**: Bastion architecture, network isolation, proper TLS
- **Reproducible**: Destroy and recreate identical cluster in ~5 minutes

## Architecture

**Bastion Pattern:**
- Hypervisor: Virtualization host (192.168.1.x)
- Bastion: Jump box with cluster tools (192.168.122.13)
- Cluster: Isolated network (192.168.122.10-12)
- Access: Laptop → SSH → Bastion → Cluster

**Node Specifications:**
- Control Plane/Workers: 6 vCPUs, 10GB RAM, 80GB disk
- Bastion: 2 vCPUs, 4GB RAM, 80GB disk (inherited from base volume)
- Ubuntu 24.04 LTS
- k3s v1.34.3+k3s1 (pinned, with TLS SAN for 127.0.0.1)

**Network:**
- Hypervisor network: 192.168.1.0/24 (physical LAN)
- Cluster network: 192.168.122.0/24 (libvirt NAT)
- Network isolation: VMs not directly accessible from LAN
- Static IPs via cloud-init
- flannel CNI for pod networking

**Deployment:**
- Packer builds Ubuntu base image
- Terraform provisions VMs via libvirt provider
- cloud-init installs k3s (cluster) or tools (bastion)

**Tools on Bastion:**
- kubectl (cluster management)
- k9s (cluster TUI)
- flux CLI (GitOps)
- helm (package manager)

For detailed architecture, see [docs/kpi-architecture.md](docs/kpi-architecture.md)

### Why Bastion Architecture?

**Security & Isolation:**
- Cluster nodes isolated on private network (192.168.122.0/24)
- Single controlled entry point for cluster access
- Reduces attack surface (no direct external access to cluster)

**Production Pattern:**
- Mirrors enterprise bastion/jump box architecture
- Translates directly to AWS (bastion in public subnet, cluster in private)
- Demonstrates defense-in-depth security principles

**Operational Benefits:**
- All cluster tools pre-installed and configured on bastion
- Consistent environment for cluster management
- TLS verification works correctly (k3s cert includes 127.0.0.1 SAN)
- No local tool installation required (kubectl, k9s, flux, helm on bastion)

**For Internet Access:**
- Workloads accessible via Cloudflare Tunnel (outbound connections)
- No router port forwarding or firewall rules needed
- NAT network doesn't limit ingress capabilities

## Prerequisites

**On hypervisor host:**
- Ubuntu 24.04 LTS
- libvirt/QEMU/KVM installed
- Packer installed (for building base image)
- SSH access from laptop

**On laptop (management station):**
- Docker or Podman (for containerized Terraform)
- SSH access to hypervisor host
- SSH key pair (`~/.ssh/id_rsa`)
- SSH config configured (see `config-templates/ssh-config.example`)

**Hardware:**
- 36GB+ RAM (34GB for VMs + 2GB host)
- 320GB+ free disk space (4x 80GB VMs)
- 20+ CPU cores recommended

## Common Operations

**Rebuild cluster (preserves base image):**
```bash
cd terraform-libvirt

# 1. Destroy cluster (~1 minute)
./scripts/destroy-cluster.sh
# Type "yes" when prompted

# 2. Redeploy cluster (~7 seconds for VMs + ~7 min cloud-init)
docker compose run --rm terraform apply

# 3. Verify nodes are ready
ssh kpi-cp-01 'cloud-init status --wait'
ssh kpi-cp-01 'sudo k3s kubectl get nodes'

# 4. kubectl should still work (tunnel persists)
kubectl get nodes
```

**Update base image:**
```bash
# On hypervisor host (~3.5 minutes)
cd ~/kubernetes-platform-infrastructure/packer/k3s-node
packer build .

# From laptop: reimport and redeploy
cd terraform-libvirt
./scripts/destroy-cluster.sh
docker compose run --rm terraform import libvirt_volume.base \
  /home/YOUR_USER/libvirt_images/k3s-node-ubuntu-24.04.qcow2
docker compose run --rm terraform apply
```

**Access cluster:**
```bash
# RECOMMENDED: Via bastion host (production pattern)
ssh kpi-bastion-01
kubectl get nodes  # kubeconfig pre-configured
k9s                # interactive cluster TUI

# Alternative: kubectl from laptop (through bastion tunnel)
export KUBECONFIG=~/.kube/kpi.yaml
kubectl get nodes

# Direct SSH to control plane (for debugging)
ssh kpi-cp-01
sudo k3s kubectl get nodes

# From hypervisor (emergency access)
ssh hypervisor
ssh ubuntu@192.168.122.10
sudo k3s kubectl get nodes
```

## Cost

**Sandbox environment (current):**
- Infrastructure: $0/month (runs on spare capacity)
- Electricity: ~$10-20/month (absorbed in existing costs)
- **Net incremental cost: $0/month**

**AWS equivalent (for comparison):**
- EKS control plane: ~$73/month
- 3x EC2 instances: ~$45/month
- Networking/storage: ~$20/month
- **Total: ~$138/month**

## Documentation

- **[Architecture Guide](docs/kpi-architecture.md)** - Complete technical architecture
- **[ADRs](docs/adrs/)** - Architecture decision records
- **[ZaveStudios Platform](https://github.com/zavestudios/zavestudios)** - Overall platform overview

## Next Steps

After cluster is operational:

1. **Bootstrap Flux GitOps** - Platform services management
2. **Deploy Big Bang** - DoD DevSecOps baseline (GitLab, ArgoCD, Istio, monitoring)
3. **Onboard tenant applications** - Deploy apps via ArgoCD

See [ZaveStudios roadmap](https://github.com/zavestudios/zavestudios#current-status) for current phase status.

## Part of ZaveStudios Platform

This infrastructure hosts multiple tenant applications:
- **xavierlopez.me**: Portfolio and blog (Jekyll)
- **panchito**: Real estate ETL service (Python/Flask/Celery)
- **thehouseguy**: Real estate application (Rails)
- **rigoberta**: Rails reference template

Each application has:
- Isolated Kubernetes namespace
- Dedicated database tenant in [pg-multitenant](https://github.com/zavestudios/pg-multitenant)
- Deployment via ArgoCD GitOps

---

**Maintainer:** Xavier Lopez  
**Portfolio:** [xavierlopez.me](https://xavierlopez.me)  
**Platform:** [ZaveStudios](https://github.com/zavestudios/zavestudios)
