# ADR-003: Flux and ArgoCD Separation

**Status:** Accepted  
**Date:** 2025-12-31  
**Author:** Xavier Lopez  
**Tags:** platform, gitops, kubernetes, operations

## Context

GitOps is the deployment methodology for ZaveStudios, requiring a continuous deployment tool to sync Git repository state with the Kubernetes cluster. The two leading GitOps tools are:
- **Flux CD:** CNCF graduated project, pull-based GitOps, Kubernetes-native
- **ArgoCD:** CNCF graduated project, pull-based GitOps, web UI focused

Both tools serve similar purposes but have different strengths. The platform needs to manage:
- Platform infrastructure services (Big Bang, monitoring, service mesh, etc.)
- Application workloads (web apps, data pipelines, AI services)

Demonstrating expertise with both tools adds portfolio value, but running both adds complexity.

## Decision

We will use **both Flux CD and ArgoCD with clear separation of concerns**:

- **Flux CD:** Manages platform-level services
  - Big Bang deployment and configuration
  - Platform infrastructure (cert-manager, ingress controllers)
  - GitLab runners and CI/CD infrastructure
  - Monitoring stack (Prometheus, Grafana)
  - Service mesh (Istio)

- **ArgoCD:** Manages application-level workloads
  - Web applications (xavierlopez.me, portfolio sites)
  - Data engineering pipelines
  - AI/ML services
  - Tenant/demo applications

Big Bang deploys ArgoCD as one of its packages, enabling this separation.

## Rationale

### Pros
- **Clear separation of concerns:** Platform vs. application lifecycle management
- **Tool expertise demonstration:** Shows proficiency with both leading GitOps tools
- **Best-of-both-worlds:** Leverage Flux's Kubernetes-native design for platform, ArgoCD's UI for apps
- **Operational boundaries:** Platform changes don't affect app deployments and vice versa
- **Big Bang integration:** Big Bang naturally uses Flux, can deploy ArgoCD as a package
- **Portfolio depth:** More impressive than single-tool approach

### Cons
- **Added complexity:** Two GitOps systems to maintain and monitor
- **Learning curve:** Requires understanding both tools' operational models
- **Potential conflicts:** Must carefully manage resource ownership
- **Resource overhead:** Two controllers consuming cluster resources
- **Operational burden:** Two sets of configurations, troubleshooting processes, upgrade paths

## Alternatives Considered

### Option 1: Flux CD Only
**Description:** Use Flux for all GitOps operations (platform and applications)

**Pros:**
- Single tool to learn and maintain
- Kubernetes-native CRDs (HelmRelease, Kustomization)
- Lower resource overhead
- Simpler operational model
- Deep integration with Big Bang (native choice)

**Cons:**
- No web UI for application deployment visualization
- Limited application-level features (compared to ArgoCD)
- Less portfolio breadth (single tool)
- Misses opportunity to showcase ArgoCD expertise

**Why not chosen:** Misses opportunity to demonstrate expertise with ArgoCD, which is widely used for application deployments in enterprises.

### Option 2: ArgoCD Only
**Description:** Use ArgoCD for all GitOps operations, including Big Bang

**Pros:**
- Single tool to learn and maintain
- Excellent web UI for all deployments
- Strong application-focused features
- Popular in application development teams

**Cons:**
- Big Bang natively expects Flux (requires workarounds)
- Less suitable for infrastructure-level operations
- Heavier resource footprint than Flux
- Would require significant Big Bang customization

**Why not chosen:** Big Bang's native integration with Flux makes this the natural choice for platform operations. Fighting against Big Bang's design is counterproductive.

### Option 3: No GitOps (Direct Helm/Kubectl)
**Description:** Deploy manually or via CI/CD without GitOps controllers

**Pros:**
- No GitOps controller overhead
- Simpler architecture
- Direct control over deployments

**Cons:**
- No continuous reconciliation (configuration drift risk)
- No audit trail via Git
- Misses opportunity to demonstrate GitOps expertise
- Not aligned with modern platform engineering practices
- Big Bang requires GitOps operators

**Why not chosen:** GitOps is fundamental to modern platform engineering. Not demonstrating this capability would be a significant portfolio gap.

## Consequences

### Positive
- **Expertise showcase:** Portfolio demonstrates proficiency with both major GitOps tools
- **Clear boundaries:** Platform stability isolated from application changes
- **Best practices:** Each tool used for its strengths (Flux for infra, ArgoCD for apps)
- **Interview talking points:** Can discuss trade-offs and operational experience with both
- **Flexibility:** Different teams/workloads can use appropriate tool

### Negative
- **Operational complexity:** Two systems to monitor, upgrade, troubleshoot
- **Resource utilization:** ~500MB additional memory for ArgoCD components
- **Learning investment:** Must maintain expertise in both tools
- **Potential confusion:** Must clearly document which tool manages which resources
- **Coordination overhead:** Changes affecting both layers require careful sequencing

### Neutral
- **Industry standard:** Many organizations use multiple GitOps tools for different purposes
- **Resource overlap:** Both tools watch Git repositories, some duplication of effort
- **Upgrade cadence:** Two tools have independent release schedules

## Implementation

### Steps
1. Install Flux during bootstrap phase (before Big Bang)
2. Configure Flux to deploy Big Bang helm chart
3. Enable ArgoCD package in Big Bang values
4. Big Bang deploys ArgoCD via Flux
5. Configure ArgoCD for application repository sync
6. Document ownership boundaries in architecture docs
7. Create monitoring for both GitOps controllers
8. Establish operational procedures for each tool

### Timeline
- Flux installation: Phase 1 (manual bootstrap)
- ArgoCD deployment: Phase 2 (via Big Bang)
- Application onboarding: Phase 3 (ongoing)

### Success Criteria
- Both Flux and ArgoCD operational and healthy
- Clear documentation of which tool manages which resources
- No resource ownership conflicts
- Platform services reconcile via Flux
- Applications reconcile via ArgoCD
- Both tools monitored by Prometheus
- Deployment workflows documented for each tool

## Operational Boundaries

### Flux CD Manages
```
Namespaces:
├── flux-system (Flux itself)
├── bigbang (Big Bang helm chart)
├── istio-system (service mesh)
├── monitoring (Prometheus, Grafana)
├── gitlab (GitLab and runners)
└── cert-manager (certificate management)
```

### ArgoCD Manages
```
Namespaces:
├── argocd (ArgoCD itself - deployed by Big Bang)
├── portfolio (xavierlopez.me site)
├── data-platform (data engineering pipelines)
├── ai-services (ML model serving)
└── demo-apps (demonstration applications)
```

### Ownership Rules
- **Platform namespaces:** Managed by Flux, never touch with ArgoCD
- **Application namespaces:** Managed by ArgoCD, Flux ignores
- **Shared resources:** CRDs, cluster-level configs managed by Flux
- **ArgoCD itself:** Deployed and updated by Big Bang/Flux

## Related Decisions

- [ADR-001: EKS Over Self-Managed](001-eks-over-self-managed.md) - EKS provides foundation for both tools
- Future ADR: Application repository structure and deployment patterns
- Future ADR: Multi-tenancy and namespace isolation strategy

## References

- [Flux CD Documentation](https://fluxcd.io/flux/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Big Bang GitOps Pattern](https://docs-bigbang.dso.mil/latest/docs/understanding-bigbang/package-architecture/gitops/)
- [CNCF GitOps Principles](https://opengitops.dev/)

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2025-12-31 | Initial version | Xavier Lopez |
