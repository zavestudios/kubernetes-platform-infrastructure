# ADR-004: Hybrid Sandbox + AWS Cloud-Ready Architecture

**Status:** Accepted  
**Date:** 2024-12-31  
**Author:** Xavier Lopez  
**Tags:** infrastructure, cost, hybrid-cloud, career-strategy

## Context

ZaveStudios was initially designed as an AWS-only platform running 24/7 on EKS. However, my [career coach](https://github.com/dagan), and I concluded that paying $150-200/month for AWS infrastructure is unnecessary when:
1. A sandbox with QEMU/libvirt already exists and has capacity
2. AWS expertise can be demonstrated through Infrastructure as Code without live deployment
3. The platform can be deployed to AWS on-demand for interviews and demonstrations

This ADR documents the decision to run the primary platform in a sandbox while maintaining AWS-ready Terraform code.

## Decision

We will implement a **hybrid architecture** with two deployment targets:

**Primary Deployment (Sandbox):**
- k3s cluster running on QEMU/libvirt virtual machines
- Runs 24/7 at zero cost
- Hosts all platform services and applications
- Accessible via Cloudflare Tunnel (no port forwarding required)
- Production-grade operations and uptime

**On-Demand Deployment (AWS):**
- Full Terraform codebase for EKS + infrastructure
- Deploy to AWS for interviews, demonstrations, or testing
- Same manifests work in both environments
- Destroy after use to minimize costs
- Proves AWS expertise through working IaC

## Rationale

### Pros

**Financial:**
- **Saves $150-200/month**
- Zero ongoing AWS costs
- Can deploy to AWS for $10-20 for a weekend demo
- Demonstrates financial discipline and cost awareness

**Career Presentation:**
- **Better interview story:** "I built this to run anywhere - cost-optimized for development, cloud-ready for production"
- Shows hybrid cloud thinking (not just cloud-only dogma)
- Demonstrates infrastructure portability
- Proves AWS skills without ongoing spend

**Technical:**
- Same GitOps workflows work in both environments
- Environment parity through consistent tooling (Flux, ArgoCD, Big Bang)
- Forces cloud-agnostic design decisions
- Tests true infrastructure as code (can rebuild anywhere)

**Learning:**
- AWS SA Pro certification study via Terraform modules and architecture
- Daily hands-on Kubernetes ops with k3s (CKAD prep)
- Hybrid cloud patterns (common in enterprises)
- Multi-environment deployment strategies

### Cons

**No Live AWS Ops:**
- Not operating EKS 24/7
- Miss day-to-day AWS-specific operational learning
- Can't point to live AWS resources in interviews

**Mitigation:** Terraform modules are production-ready and can deploy working infrastructure on-demand. AWS operational knowledge comes from on-demand deployments and certification study.

**Network Exposure:**
- Home lab requires Cloudflare Tunnel for external access
- Public IP not directly controlled
- Potential security considerations

**Mitigation:** Cloudflare Tunnel provides secure access without port forwarding. Service mesh (Istio) provides defense in depth.

**Sandbox Reliability:**
- Single point of failure (home infrastructure)
- No HA across physical machines
- Power/network outages affect platform

**Mitigation:** Acceptable for portfolio use case. Document RTO/RPO. Can failover to AWS if needed.

## Alternatives Considered

### Option 1: AWS-Only (Original Plan)
**Description:** Run everything in AWS EKS 24/7

**Pros:**
- Live AWS operational experience
- Can point to running AWS resources anytime
- Industry-standard production environment

**Cons:**
- $150-200/month
- Same AWS skills can be demonstrated via IaC
- No cost advantage during unemployment

**Why not chosen:** Financial burden. IaC proves AWS competency equally well.

### Option 2: Sandbox Only, No AWS IaC
**Description:** Run on sandbox, don't create AWS Terraform

**Pros:**
- Zero cost
- Simpler scope (one environment)

**Cons:**
- No AWS architecture demonstration
- Can't quickly deploy to cloud for demos
- Doesn't support AWS SA Pro study goals
- Limits career positioning

**Why not chosen:** AWS IaC is critical for career goals and certification. The Terraform modules provide AWS skill demonstration without ongoing cost.

### Option 3: Managed Kubernetes (GKE, AKS, etc.)
**Description:** Use different cloud provider for cost

**Pros:**
- Some managed K8s options cheaper than EKS
- Still cloud experience

**Cons:**
- Resume/experience heavily AWS-focused
- AWS SA Pro certification in progress
- Dilutes AWS expertise demonstration
- Still costs money monthly

**Why not chosen:** AWS alignment with career goals makes EKS the natural cloud choice. Home lab provides zero-cost alternative.

### Option 4: Kubernetes-as-a-Service (Civo, Linode, etc.)
**Description:** Use cheaper managed K8s offerings

**Pros:**
- Much cheaper than EKS (~$20-40/month)
- Still managed control plane experience

**Cons:**
- Not AWS (certification/career focus)
- Less relevant to enterprise job market
- Still ongoing cost
- Less name recognition

**Why not chosen:** Same as Option 3 - AWS focus is strategic for career goals.

## Consequences

### Positive

**Financial Discipline Demonstrated:**
- Zero monthly infrastructure
- Can deploy to AWS for <$20 when needed
- Shows FinOps thinking and cost awareness
- Money saved for other career investments

**Stronger Portfolio Story:**
- "Cloud-ready, not cloud-dependent" architecture
- Hybrid cloud experience (common in enterprises)
- Infrastructure portability proven through multi-environment support
- Cost-conscious engineering decisions
- **Complete IaC pipeline:** Packer → Terraform → Kubernetes

**AWS Skills Still Demonstrated:**
- Complete Terraform codebase for EKS/VPC/services
- Can deploy working AWS infrastructure on-demand
- AWS SA Pro study integrated with platform
- Architecture decisions documented with AWS rationale
- **Same Packer templates build both QEMU and AMI images**

**IaC Mastery Demonstrated:**
- Terraform with multiple providers (libvirt, AWS)
- Packer with multiple builders (QEMU, Amazon EBS)
- Complete automation from base image through application deployment
- Infrastructure portability in practice, not theory
- Interview story: "I use the same IaC tools for both environments - just different providers/builders"

**Operational Experience:**
- Daily k8s operations with k3s (CKAD prep)
- Platform engineering at zero cost
- Real production workflows (GitOps, monitoring, applications)
- 24/7 uptime objectives

**Flexibility:**
- Can deploy to AWS anytime (interviews, testing)
- Can switch to AWS full-time after employment
- Multi-cloud patterns demonstrated
- Not locked to single infrastructure provider

### Negative

**Perception Risk:**
- Could be seen as "not real cloud experience"
- Home lab might seem less professional
- No live AWS resources to show

**Mitigation:** Strong interview narrative: "I architected for portability. Daily ops on sandbox, but cloud-ready via Terraform. Want to see AWS deployment? I can spin it up right now."

**Sandbox Limitations:**
- Single AZ by nature (no multi-AZ HA)
- Limited by home hardware resources
- Dependent on home power/internet

**Mitigation:** Acceptable for portfolio. Document as design constraint. Demonstrate understanding of production multi-AZ patterns.

**No AWS-Specific Operational Learnings:**
- Missing EKS-specific operational knowledge
- No AWS service integration experience (RDS, ALB, etc.)
- Can't speak to day-to-day AWS ops

**Mitigation:** Terraform modules include these services. On-demand deployments provide exposure. Certification study covers concepts.

### Neutral

**Environment Parity:**
- Same manifests work in both environments
- Tests true cloud-agnostic design
- Forces infrastructure portability

**Hybrid Cloud Patterns:**
- Common in enterprises (on-prem + cloud)
- Demonstrates multi-environment thinking
- Relevant to many job opportunities

## Implementation

### Sandbox Setup

**Infrastructure Automation:**
- **Image Building:** Packer with QEMU builder for custom hardened base images
- **Infrastructure Provisioning:** Terraform with libvirt provider for VM management
- **Configuration Management:** Cloud-init for k3s installation and node configuration
- **Phase 1 Approach:** Start with Ubuntu cloud images, migrate to Packer-built images in Phase II

**Infrastructure:**
- k3s cluster on QEMU/libvirt (3 VMs: 1 control plane, 2 workers)
- VM specs: 4 vCPU, 8GB RAM, 50GB disk per node
- Local container registry (Harbor or Docker Registry)
- NFS or local-path storage provisioner
- Cloudflare Tunnel for secure external access

**Terraform Libvirt Provider:**
```hcl
# Example terraform-modules/libvirt-vm structure
resource "libvirt_volume" "vm_disk" {
  name           = "${var.vm_name}.qcow2"
  base_volume_id = var.base_image_id
  pool           = var.storage_pool
  size           = var.disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "vm_init" {
  name      = "${var.vm_name}-init.iso"
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    hostname    = var.vm_name
    k3s_role    = var.k3s_role
    k3s_token   = var.k3s_token
    k3s_server  = var.k3s_server_url
  })
}

resource "libvirt_domain" "vm" {
  name   = var.vm_name
  memory = var.memory_mb
  vcpu   = var.vcpu_count
  
  cloudinit = libvirt_cloudinit_disk.vm_init.id
  
  disk {
    volume_id = libvirt_volume.vm_disk.id
  }
  
  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }
}
```

**Packer Image Building (Phase II):**
```hcl
# Same template, different builders
source "qemu" "k3s_base" {
  iso_url      = "https://releases.ubuntu.com/22.04/..."
  format       = "qcow2"
  disk_size    = "50G"
  # Shared provisioning scripts
}

source "amazon-ebs" "k3s_base" {
  region        = "us-east-1"
  instance_type = "t3.medium"
  # Same provisioning scripts
}

build {
  sources = ["source.qemu.k3s_base", "source.amazon-ebs.k3s_base"]
  
  provisioner "shell" {
    scripts = [
      "scripts/update-packages.sh",
      "scripts/harden-os.sh",
      "scripts/install-k3s-prereqs.sh"
    ]
  }
}
```

**Repository Organization:**
```
GitHub:
- terraform-modules/
  ├── libvirt-vm/          # Reusable VM module
  ├── k3s-cluster/         # k3s cluster module (uses libvirt-vm)
  ├── aws-vpc/             # AWS VPC module
  └── aws-eks/             # AWS EKS module

- packer-images/
  └── k3s-base/
      ├── k3s-base.pkr.hcl         # Multi-builder template
      ├── scripts/                  # Shared provisioning
      └── cloud-init/               # Base configuration

GitLab:
- terraform-environments/
  ├── home-lab/            # Home lab k3s cluster
  └── aws-demo/            # AWS EKS cluster
```

**Platform Deployment:**
- Flux installed via bootstrap script
- Big Bang deployed by Flux
- All platform services (GitLab, ArgoCD, monitoring)
- Applications deployed via ArgoCD

**Networking:**
- Cloudflare Tunnel eliminates need for port forwarding
- TLS termination at Istio ingress
- No direct public IP exposure

**Why This Tooling:**
- **Terraform libvirt provider:** Same IaC tool as AWS, different provider
- **Packer multi-builder:** Single template builds both QEMU and AMI images
- **Complete portability:** Image build → Infrastructure → Configuration all reproducible
- **Portfolio story:** "I use Terraform everywhere - libvirt for sandbox, AWS for cloud"

### AWS Terraform Modules

**Modules to Create:**
- VPC (single-AZ, cost-optimized)
- EKS (spot instances, Karpenter)
- RDS (optional, for database demos)
- S3/DynamoDB (Terraform state)

**Environments:**
- `aws-demo` environment for on-demand deployments
- Terraform plan runs in GitLab CI/CD
- Manual terraform apply for AWS deployments
- Automated destroy after demonstrations

### Environment Parity

**Same Manifests:**
- Application deployments work in both environments
- Platform configuration adjustable via values
- Storage class differences handled via configuration

**Differences:**
- k3s: local storage, NodePort services, local registry
- EKS: EBS storage, LoadBalancer services, ECR

### Cost Tracking

**Sandbox:**
- $0/month infrastructure cost
- Electricity cost absorbed by existing sandbox
- Internet bandwidth sufficient

**AWS:**
- Budget for on-demand demos: ~$20/weekend
- Deploy Friday, demo Saturday, destroy Sunday
- Total cost for 4-6 month job search: <$200

## Documentation Updates

### ADRs to Update:
- **ADR-001:** Update rationale (k3s primary, EKS proven via IaC)
- **ADR-002:** Single-AZ still applies to AWS deployments
- **ADR-003:** Flux/ArgoCD separation remains unchanged

### Architecture Docs:
- Update diagrams showing both sandbox and AWS
- Document environment parity strategy
- Cloudflare Tunnel configuration
- Bootstrap procedures for both environments

### Certification Mappings:
- AWS SA Pro: "Demonstrated via Terraform, deployed on-demand"
- CKAD: "Daily hands-on with k3s cluster"

## Success Criteria

### Sandbox Platform:
- [ ] k3s cluster operational 24/7
- [ ] All platform services deployed
- [ ] Applications running and accessible
- [ ] Cloudflare Tunnel configured
- [ ] Monitoring and observability working
- [ ] GitOps workflows functioning

### AWS Terraform:
- [ ] Complete VPC module
- [ ] Complete EKS module
- [ ] Working terraform-environments/aws-demo
- [ ] Can deploy full stack in ~20 minutes
- [ ] Can destroy cleanly
- [ ] Same manifests work in AWS

### Portfolio Presentation:
- [ ] Architecture diagram shows both environments
- [ ] Documentation explains hybrid approach
- [ ] Interview talking points prepared
- [ ] Can demo AWS deployment on-demand
- [ ] Cost savings documented and quantified

### Certification Alignment:
- [ ] AWS SA Pro study integrated with Terraform work
- [ ] CKAD daily practice on k3s cluster
- [ ] Both cert mappings updated for hybrid architecture

## Related Decisions

- [ADR-001: EKS Over Self-Managed](001-eks-over-self-managed.md) - Superseded by this ADR
- [ADR-002: Single-AZ Deployment](002-single-az-deployment.md) - Still applies to AWS deployments
- [ADR-003: Flux and ArgoCD Separation](003-flux-and-argocd-separation.md) - Unchanged

## Future Considerations

**Sandbox Expansion:**
- Add physical machines for true HA if needed
- Implement bare-metal load balancing (MetalLB)
- Expand storage with NAS integration

**AWS Cost Optimization:**
- If deploying to AWS long-term, implement all optimization strategies from ADR-002
- Consider Reserved Instances or Savings Plans once committed
- Use Spot instances with Karpenter as designed

## References

- [k3s Documentation](https://docs.k3s.io/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Hybrid Cloud Architecture Patterns](https://aws.amazon.com/hybrid/)
- [Platform Engineering on a Budget](https://www.cncf.io/blog/) - Various CNCF articles

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2024-12-31 | Initial version | Xavier Lopez |
