# ADR-005: osquery for Platform Monitoring

**Status:** Proposed
**Date:** 2026-02-24
**Author:** Claude (via Xavier Lopez)
**Tags:** monitoring, security, observability, osquery

## Context

ZaveStudios is evaluating osquery as a potential monitoring and security visibility tool for the kubernetes-platform-infrastructure. The Ansible repository already contains an osquery role (v5.10.2) that is not currently deployed to the k3s cluster.

### What is osquery?

osquery is an open-source endpoint visibility tool that exposes operating system data as SQL tables, enabling real-time queries about system state. It provides:
- System introspection (processes, network, users, files)
- SQL interface for querying OS internals
- Cross-platform support (Linux, macOS, Windows)
- Real-time monitoring capabilities
- Agent-based architecture

### Current Infrastructure

**Environment:**
- Sandbox k3s cluster: 3 nodes (1 control plane, 2 workers) + 1 bastion
- Scale: 4 VMs total (~26 vCPU, ~34GB RAM)
- Network: Private 192.168.122.0/24 (libvirt)
- Workload: Multi-tenant containerized platform
- Management: Terraform + Ansible automation

**Existing Monitoring:**
- k9s (interactive cluster management on bastion)
- kubectl for ad-hoc queries
- Likely Prometheus/Grafana (or planned)

## Decision Criteria

The evaluation considers:
1. **Current Need:** Does the sandbox environment benefit from osquery?
2. **Operational Overhead:** Setup, maintenance, resource consumption
3. **Alternative Solutions:** Kubernetes-native monitoring tools
4. **Future Value:** Benefits when moving to production
5. **Team Bandwidth:** Available capacity for new tooling

## Analysis

### Use Cases Evaluated

#### ❌ Low Value for Current Setup

**1. Container/Pod Monitoring**
- Kubernetes has better native tools (kubectl, k9s, metrics-server)
- Container visibility limited from host perspective
- Pod lifecycle too dynamic for host-based monitoring
- **Better:** Prometheus + Grafana, kubectl

**2. Security Threat Detection (Basic)**
- Sandbox environment with no production traffic
- Limited attack surface (private network)
- No compliance requirements
- Direct SSH access available for investigation
- **Better:** Falco (Kubernetes-native runtime security)

**3. Compliance Auditing**
- No regulatory requirements for sandbox
- No customers requiring compliance attestation
- Manual audits sufficient at current scale
- **Better:** Kube-bench for CIS benchmarks when needed

**4. Fleet Management**
- Only 4 VMs total
- Ansible already provides inventory and state management
- kubectl provides cluster-wide queries
- **Better:** Existing tooling sufficient

#### ✅ Potential Value (Future)

**1. Production Security Posture**
- Monitor k3s node host security
- Detect unauthorized access
- Track package versions for vulnerability management
- **Value when:** Production deployment with sensitive data

**2. Intrusion Detection (Advanced)**
- Real-time privilege escalation detection
- Unauthorized binary execution alerts
- Network connection anomaly detection
- **Value when:** Security becomes critical requirement

**3. Compliance Requirements**
- Automated CIS benchmark checking
- Continuous compliance monitoring
- Evidence collection (SOC2, ISO 27001)
- **Value when:** Customers require attestation

### Operational Overhead

**Setup Complexity:**
- Installation: Easy (Ansible role exists)
- Configuration: Moderate (query packs, TLS certs if centralized)
- Time: 4-8 hours initial, 8-16 hours tuning

**Ongoing Maintenance:**
- Query pack updates and tuning
- Alert triage and investigation
- Performance monitoring (5-10% CPU during queries)
- Log storage management (GB/day depending on schedule)
- Version updates and security patches
- **Estimated:** 2-4 hours/month

**Resource Requirements:**
- Agent: ~100-200MB RAM per node × 4 = 400-800MB
- Central server (if used): 1-2 CPU cores, 2-4GB RAM
- Storage: ~50-100GB/year for logs

### Cost-Benefit Score

| Factor | Weight | Score (1-5) | Weighted |
|--------|--------|-------------|----------|
| Current Need | High (3x) | 1 | 3 |
| Ease of Implementation | Low (1x) | 4 | 4 |
| Operational Overhead | High (3x) | 2 | 6 |
| Alternative Availability | High (2x) | 5 | 10 |
| Future Value | Medium (2x) | 3 | 6 |
| Team Bandwidth | High (3x) | 2 | 6 |
| **Total** | | | **35/70** |

**Interpretation:** Score <40/70 = Not recommended

## Decision

**NOT RECOMMENDED** for current ZaveStudios infrastructure.

### Rationale

1. **Overkill for current scale:** 4-node sandbox doesn't warrant the operational overhead
2. **Better alternatives exist:** Kubernetes-native tools better suited for container workloads
3. **Negative ROI:** Operational cost exceeds benefits at current scale
4. **Wrong tool for workload:** osquery excels at bare-metal/VM fleets, not containerized platforms
5. **Limited bandwidth:** Team focus better spent on platform core functionality

### What to Do Instead

**Short-term (Current Phase):**
- Focus on core platform functionality
- Deploy Kubernetes-native monitoring (Prometheus + Grafana if not present)
- Use kubectl and k9s for observability
- Enable Kubernetes audit logging

**Medium-term (6-12 months):**
- Re-evaluate when moving beyond sandbox
- Consider if managing >20 hosts
- Evaluate if compliance requirements emerge

**Long-term (12+ months):**
- Consider for production with sensitive data
- Deploy if compliance required (SOC2, ISO 27001)
- Use if dedicated security engineer joins team

## Consequences

### If Rejected (Recommended)

**Positive:**
- ✅ Team bandwidth focused on core platform
- ✅ Simpler operational stack
- ✅ Lower resource consumption
- ✅ No additional maintenance burden

**Negative:**
- ❌ Less host-level visibility (mitigated by SSH access)
- ❌ Manual compliance checks if needed
- ❌ No unified fleet querying (only 4 hosts, acceptable)

**Mitigation:**
- Keep osquery role in Ansible for future use
- Use Kubernetes-native monitoring tools
- Re-evaluate at production deployment

### If Accepted (Not Recommended)

**Positive:**
- ✅ Host-level visibility across cluster
- ✅ SQL-based querying capability
- ✅ Foundation for future compliance needs

**Negative:**
- ❌ Operational overhead (setup, tuning, maintenance)
- ❌ Resource consumption (CPU, memory, storage)
- ❌ Learning curve for team
- ❌ Diverts focus from core platform work

## Alternatives Considered

### For Kubernetes Monitoring
- **Prometheus + Grafana:** Standard k8s monitoring, rich ecosystem
- **kubectl + k9s:** Ad-hoc queries, no overhead (already present)
- **Metrics Server:** Basic resource metrics

### For Security
- **Falco:** Kubernetes-native runtime security, CNCF project
- **Kubernetes Audit Logs:** Track API access, built-in feature
- **Network Policies:** Traffic control, native feature

### For Compliance (Future)
- **Trivy:** Image/config scanning (already in use)
- **Kube-bench:** CIS Kubernetes benchmark checker
- **OPA Gatekeeper:** Policy enforcement as code

## References

- [osquery Official Documentation](https://osquery.io/)
- [Ansible osquery role](https://github.com/zavestudios/ansible/tree/main/roles/osquery)
- [Falco - Kubernetes Runtime Security](https://falco.org/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)

## Related ADRs

- [ADR-004: Hybrid Sandbox + AWS Architecture](004-hybrid-sandbox-aws-architecture.md) - Infrastructure context

## Review Schedule

**Next Review:** Upon any of these triggers:
- Moving to production environment
- Customer compliance requirements emerge
- Managing >20 hosts
- Security engineer joins team
- 6 months (2026-08-24)
