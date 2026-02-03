# ADR-001: EKS Over Self-Managed Kubernetes

**Status:** Superseded by [ADR-004: Hybrid Sandbox + AWS Architecture](004-hybrid-sandbox-aws-architecture.md)  
**Date:** 2024-12-31  
**Superseded Date:** 2024-12-31  
**Author:** Xavier Lopez  
**Tags:** infrastructure, aws, eks, kubernetes, *superseded*

**Note:** This ADR documents the original AWS-only architecture decision. The project has since pivoted to a hybrid approach (sandbox k3s + AWS on-demand). See [ADR-004](004-hybrid-sandbox-aws-architecture.md) for the current architecture rationale.

## Context

ZaveStudios requires a Kubernetes cluster to run the Big Bang platform and application workloads. The choice of Kubernetes distribution affects:
- Operational complexity and maintenance burden
- Monthly infrastructure costs
- Demonstration of AWS-native architecture skills
- Control plane reliability and availability
- Portfolio appeal to interested observers

The platform targets a $150-200/month AWS budget while showcasing production-grade architecture patterns.

## Decision

We will use **AWS Elastic Kubernetes Service (EKS)** as the Kubernetes distribution for ZaveStudios.

The cluster will be configured with:
- Control plane managed by AWS
- Worker nodes on EC2 spot instances (t3a.medium)
- Karpenter for autoscaling
- Single availability zone deployment (us-east-1a)
- Standard AWS networking (VPC CNI, AWS Load Balancer Controller)

## Rationale

### Pros
- **Industry alignment:** EKS is the standard Kubernetes offering for AWS environments, demonstrating relevant enterprise skills
- **Reduced operational burden:** Managed control plane eliminates etcd management, control plane upgrades, and HA concerns
- **AWS integration:** Native integration with IAM, CloudWatch, ECR, and other AWS services
- **Career relevance:** Most enterprise AWS environments use EKS, making this experience directly transferable
- **Reliability:** AWS SLA covers control plane availability
- **Security:** Automatic security patches for control plane

### Cons
- **Cost:** EKS control plane costs ~$73/month (unavoidable baseline)
- **Less control:** Cannot modify control plane configuration or access etcd directly
- **AWS lock-in:** Tied to AWS-specific Kubernetes distribution
- **Overkill for demo:** Managed control plane may be excessive for a portfolio project

## Alternatives Considered

### Option 1: Self-Managed k3s on EC2
**Description:** Deploy Rancher k3s on a single EC2 instance, managing the entire Kubernetes stack ourselves

**Pros:**
- Significant cost savings (~$30/month vs. $100+/month)
- Full control over all Kubernetes components
- Lightweight footprint suitable for smaller workloads
- Demonstrates deep Kubernetes operational knowledge

**Cons:**
- High operational burden (etcd backups, control plane upgrades, HA concerns)
- Less relevant to enterprise environments (most companies use managed Kubernetes)
- Single point of failure without HA setup
- Time spent on cluster operations vs. platform engineering showcase
- Requires expertise in lower-level Kubernetes administration

**Why not chosen:** The operational burden and reduced career relevance outweigh the cost savings. Time is better spent on platform-level capabilities than cluster operations.

### Option 2: Self-Managed k3s in Sandbox
**Description:** Run k3s on sandbox hardware (QEMU/libvirt), expose via Cloudflare Tunnel

**Pros:**
- Zero AWS compute costs
- Full control over infrastructure
- Learning opportunity for bare-metal Kubernetes

**Cons:**
- Does not demonstrate AWS architecture skills (critical for career goals)
- Home infrastructure reliability concerns
- Network exposure and security considerations
- Limits ability to showcase AWS-native services
- Less professional appearance in portfolio

**Why not chosen:** Fails to demonstrate AWS cloud architecture expertise, which is a primary objective of the portfolio.

### Option 3: Other Managed Kubernetes (GKE, AKS)
**Description:** Use Google Kubernetes Engine or Azure Kubernetes Service instead of EKS

**Pros:**
- Similar managed experience to EKS
- Multi-cloud portfolio demonstration
- Some services may be cheaper than AWS

**Cons:**
- Resume and experience heavily AWS-focused
- AWS Solutions Architect certification in progress
- Splitting cloud providers dilutes expertise demonstration
- Additional learning curve for unfamiliar services

**Why not chosen:** AWS alignment with career goals and existing expertise makes EKS the natural choice.

## Consequences

### Positive
- **Clear focus:** Can concentrate on platform engineering rather than cluster operations
- **Enterprise relevance:** Experience directly applicable to most job opportunities
- **Integration opportunities:** Easy to showcase AWS-native services (RDS, Lambda, etc.)
- **Reliability:** Managed control plane provides stable foundation for demonstrations
- **Scalability:** Can easily add features requiring AWS integration

### Negative
- **Cost baseline:** $73/month EKS control plane is unavoidable, limits budget for other services
- **Reduced flexibility:** Cannot experiment with alternative control plane configurations
- **Less depth:** Doesn't showcase deep Kubernetes control plane expertise

### Neutral
- **Standard choice:** EKS is expected for AWS environments, neither impressive nor concerning
- **Learning investment:** Time saved on operations can be invested in platform capabilities

## Implementation

### Steps
1. Create EKS cluster via Terraform in us-east-1
2. Configure single-AZ node groups with spot instances
3. Install Karpenter for autoscaling
4. Set up AWS Load Balancer Controller
5. Configure IRSA (IAM Roles for Service Accounts) for secure AWS access
6. Document cluster configuration and costs

### Timeline
- Target completion: Initial cluster deployment in Phase 1 (manual bootstrap)
- Dependencies: VPC and networking infrastructure must exist first

### Success Criteria
- EKS cluster operational and stable
- Spot instances successfully running workloads with <5% interruption rate
- Control plane costs remain at ~$73/month
- Integration with Flux and Big Bang successful
- Total cluster costs (including nodes) stay within $100-120/month range

## Related Decisions

- [ADR-002: Single-AZ Deployment](002-single-az-deployment.md) - Cost optimization through single-AZ architecture
- Future ADR: Node sizing and spot instance strategy
- Future ADR: Karpenter configuration and autoscaling policies

## References

- [AWS EKS Pricing](https://aws.amazon.com/eks/pricing/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Documentation](https://karpenter.sh/)
- [AWS Solutions Architect Pro Certification Study Materials](https://aws.amazon.com/certification/certified-solutions-architect-professional/)

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2025-12-31 | Initial version | Xavier Lopez |
