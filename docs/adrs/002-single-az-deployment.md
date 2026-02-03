# ADR-002: Single-AZ Deployment

**Status:** Accepted  
**Date:** 2025-12-31  
**Author:** Xavier Lopez  
**Tags:** infrastructure, cost, availability, aws

## Context

AWS resources can be deployed across multiple availability zones (AZs) for high availability and fault tolerance. However, multi-AZ deployments incur additional costs:
- Cross-AZ data transfer charges ($0.01-0.02/GB)
- Multiple NAT gateways ($32/month per AZ)
- Load balancer cross-AZ charges
- Increased resource overhead

ZaveStudios operates with a $150-200/month budget constraint while demonstrating production architecture patterns. The platform needs to balance cost efficiency with appropriate availability for a portfolio showcase.

## Decision

We will deploy **all ZaveStudios resources in a single availability zone** (us-east-1a in AWS us-east-1 region).

This includes:
- EKS worker nodes
- NAT gateway
- Databases and stateful services
- Application workloads

The EKS control plane remains multi-AZ by default (managed by AWS).

## Rationale

### Pros
- **Significant cost savings:** Eliminates cross-AZ data transfer charges (potentially $10-30/month)
- **Single NAT gateway:** Saves $32-64/month vs. multi-AZ NAT setup
- **Simpler networking:** Reduced complexity in subnet routing and load balancing
- **Cost discipline demonstration:** Shows financial awareness and optimization skills
- **Acceptable risk:** For a portfolio/demo platform, the availability trade-off is reasonable

### Cons
- **Reduced availability:** Single AZ failure takes down entire platform
- **Not production-best-practice:** Most production systems require multi-AZ for SLAs
- **Learning gap:** Doesn't demonstrate multi-AZ architecture patterns
- **Recovery time:** AZ-level outage requires waiting for AWS to restore, cannot failover

## Alternatives Considered

### Option 1: Multi-AZ Deployment (3 AZs)
**Description:** Distribute resources across three availability zones for maximum availability

**Pros:**
- Production-grade high availability
- Demonstrates enterprise architecture patterns
- Protects against AZ-level failures
- Better aligns with AWS Well-Architected Framework

**Cons:**
- Additional $64/month for two extra NAT gateways
- $20-40/month in cross-AZ data transfer
- More complex networking configuration
- Total additional cost: ~$80-100/month (50% budget increase)

**Why not chosen:** Cost increase is too significant for a portfolio project. The budget impact outweighs the availability benefit for this use case.

### Option 2: Two-AZ Deployment
**Description:** Deploy across two availability zones as a middle ground

**Pros:**
- Some availability improvement over single-AZ
- Lower cost than three-AZ deployment
- Demonstrates awareness of HA patterns

**Cons:**
- Still significant cost: +$50-70/month
- Doesn't provide full 3-AZ resilience
- Adds complexity without full benefit
- Two AZs insufficient for some quorum-based systems (?)

**Why not chosen:** Provides minimal additional value over single-AZ while still incurring substantial cost. Neither fish nor fowl.

### Option 3: Application-Level Multi-AZ
**Description:** Keep infrastructure in single-AZ but design applications for multi-region deployment

**Pros:**
- Demonstrates architectural thinking beyond infrastructure
- Showcases disaster recovery patterns
- Could deploy to second region on-demand

**Cons:**
- Adds complexity without current benefit
- Still incurs single-AZ infrastructure risk
- Requires more sophisticated deployment patterns

**Why not chosen:** Over-engineering for current needs. Can be revisited in future phases.

## Consequences

### Positive
- **Budget preserved:** Savings of $50-100/month enables other capabilities
- **Clear trade-off demonstration:** Portfolio shows conscious cost/availability decision-making
- **Simplified architecture:** Easier to document and explain
- **FinOps showcase:** Demonstrates financial discipline and optimization awareness
- **Risk-appropriate:** Availability level matches portfolio/demo requirements

### Negative
- **Single point of failure:** AZ outage impacts entire platform
- **Availability metrics:** Cannot demonstrate >99.9% uptime SLAs
- **Career gap:** Less multi-AZ operational experience
- **AWS best practices:** Deviates from Well-Architected Framework recommendations
- **Recovery complexity:** No automatic failover mechanisms

### Neutral
- **EKS control plane:** Remains multi-AZ regardless (managed by AWS) (?)
- **Regional scope:** Still operates across entire us-east-1 region conceptually
- **Future expansion:** Can migrate to multi-AZ if budget allows

## Implementation

### Steps
1. Design VPC with subnets in single AZ (us-east-1a)
2. Deploy single NAT gateway in chosen AZ
3. Configure EKS node groups to deploy only in selected AZ
4. Document availability expectations and RTO/RPO
5. Implement monitoring to detect AZ-level issues
6. Create runbook for AZ failure recovery

### Timeline
- Target completion: Part of initial infrastructure deployment (Phase 1)
- Dependencies: VPC design must be finalized first

### Success Criteria
- All resources successfully deployed in single AZ
- Cross-AZ data transfer charges: $0/month
- Single NAT gateway operational
- Cost savings of $50-100/month realized
- Documentation clearly explains availability trade-offs
- Monitoring alerts configured for availability tracking

## Implementation Details

### VPC Design
```
VPC: 10.0.0.0/16
├── Public Subnet: 10.0.1.0/24 (us-east-1a)
├── Private Subnet: 10.0.10.0/24 (us-east-1a)
└── NAT Gateway: Single instance in public subnet
```

### Availability Expectations
- **Target uptime:** 99.5% (allows ~3.6 hours/month downtime)
- **RTO (Recovery Time Objective):** 4 hours (waiting for AWS AZ recovery)
- **RPO (Recovery Point Objective):** <15 minutes (GitOps sync frequency)

### Monitoring
- CloudWatch alarms for EKS control plane health
- Prometheus alerts for node availability
- Uptime monitoring via external service
- Cost alerts to ensure NAT/transfer savings realized

### Risk Mitigation
- Daily backups of critical data
- GitOps ensures infrastructure is code (can rebuild)
- Documentation for manual recovery procedures
- Monitoring to detect issues quickly

## Related Decisions

- [ADR-001: EKS Over Self-Managed](001-eks-over-self-managed.md) - EKS choice sets baseline cost
- Future ADR: Disaster recovery and backup strategy
- Future ADR: Monitoring and alerting architecture

## References

- [AWS Multi-AZ Best Practices](https://docs.aws.amazon.com/whitepapers/latest/real-time-communication-on-aws/high-availability-and-scalability-on-aws.html)
- [AWS Data Transfer Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [NAT Gateway Pricing](https://aws.amazon.com/vpc/pricing/)
- [EKS Best Practices - Reliability](https://aws.github.io/aws-eks-best-practices/reliability/docs/)

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2025-12-31 | Initial version | Xavier Lopez |
