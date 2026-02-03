# kubernetes-platform-infrastructure

**Automated 3-node k3s cluster deployment on KVM/libvirt virtualization.**

Part of the [ZaveStudios multi-tenant platform](https://github.com/eckslopez/zavestudios) - provides the infrastructure layer for hosting multiple tenant applications with isolated resources.

## Quick Start

**From laptop (recommended):**

```bash
# 1. Clone repository
git clone https://github.com/eckslopez/kubernetes-platform-infrastructure.git
cd kubernetes-platform-infrastructure

# 2. Configure Terraform variables
cp terraform-libvirt/terraform.tfvars.example terraform-libvirt/terraform.tfvars
vim terraform-libvirt/terraform.tfvars

# Required: Set your SSH public key path
# ssh_public_key_path = "~/.ssh/id_rsa.pub"

# 3. Deploy cluster
cd terraform-libvirt
docker compose run --rm terraform apply

# Wait ~5 minutes for cloud-init to complete

# 4. Get kubeconfig
ssh ubuntu@192.168.122.10 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/kpi.yaml
sed -i 's/127.0.0.1/192.168.122.10/' ~/.kube/kpi.yaml

# 5. Verify cluster
export KUBECONFIG=~/.kube/kpi.yaml
kubectl get nodes -o wide
```

## What This Provides

- **3-node k3s cluster**: 1 control plane + 2 workers
- **Automated deployment**: Terraform + Packer + cloud-init
- **Static networking**: Predictable IPs (192.168.122.10-12)
- **Production patterns**: Multi-node, persistent storage, proper networking
- **Reproducible**: Destroy and recreate identical cluster in ~5 minutes

## Architecture

**Node Specifications:**
- 6 vCPUs, 10GB RAM, 80GB disk per node
- Ubuntu 24.04 LTS
- k3s v1.34.3+k3s1 (pinned)

**Network:**
- libvirt default network (192.168.122.0/24)
- Static IPs via cloud-init
- flannel CNI for pod networking

**Deployment:**
- Packer builds Ubuntu base image
- Terraform provisions VMs via libvirt provider
- cloud-init installs and configures k3s

For detailed architecture, see [docs/architecture.md](docs/architecture.md)

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

**Hardware:**
- 32GB+ RAM (30GB for VMs + 2GB host)
- 250GB+ free disk space
- 18+ CPU cores recommended

## Common Operations

**Rebuild cluster:**
```bash
cd terraform-libvirt
docker compose run --rm terraform destroy
docker compose run --rm terraform apply
# ~5 minutes to fresh cluster
```

**Update base image:**
```bash
# On hypervisor host
cd ~/kubernetes-platform-infrastructure/packer/k3s-node
packer build .

# Then redeploy from laptop
```

**Access cluster:**
```bash
# Via kubectl
export KUBECONFIG=~/.kube/kpi.yaml
kubectl get nodes

# Via SSH (troubleshooting)
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

- **[Architecture Guide](docs/architecture.md)** - Complete technical architecture
- **[ADRs](docs/adrs/)** - Architecture decision records
- **[ZaveStudios Platform](https://github.com/eckslopez/zavestudios)** - Overall platform overview

## Next Steps

After cluster is operational:

1. **Bootstrap Flux GitOps** - Platform services management
2. **Deploy Big Bang** - DoD DevSecOps baseline (GitLab, ArgoCD, Istio, monitoring)
3. **Onboard tenant applications** - Deploy apps via ArgoCD

See [ZaveStudios roadmap](https://github.com/eckslopez/zavestudios#current-status) for current phase status.

## Part of ZaveStudios Platform

This infrastructure hosts multiple tenant applications:
- **xavierlopez.me**: Portfolio and blog (Jekyll)
- **panchito**: Real estate ETL service (Python/Flask/Celery)
- **thehouseguy**: Real estate application (Rails)
- **rigoberta**: Rails reference template

Each application has:
- Isolated Kubernetes namespace
- Dedicated database tenant in [pg-multitenant](https://github.com/eckslopez/pg-multitenant)
- Deployment via ArgoCD GitOps

---

**Maintainer:** Xavier Lopez  
**Portfolio:** [xavierlopez.me](https://xavierlopez.me)  
**Platform:** [ZaveStudios](https://github.com/eckslopez/zavestudios)
