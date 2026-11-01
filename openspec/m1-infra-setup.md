# OpenSpec Change Proposal: Milestone 1 — Infrastructure Setup

- **Proposal ID**: `RFC-2026-001`
- **Milestone**: Milestone 1 (M1) — Infrastructure Setup
- **Status**: Accepted
- **Author**: Student Engineer
- **Course**: SE470 Cloud Architecture (KSE ✕ AWS Academy 2026/27)
- **Target System**: Serverless / Distributed Key-Value Store (Light DynamoDB)

---

## 1. Problem Statement & Motivation

The overarching capstone project requires building a distributed, horizontally partitioned key-value store modeled after DynamoDB across five evolutionary milestones (M1: Infra Setup, M2: Sharding & Coordinator, M3: Replication & Quorums, M4: Observability & MCP, M5: Autoscaling & Rebalancing).

Before deploying compute workloads (M2 coordinator and storage shards), a deterministic, secure, and reproducible cloud infrastructure baseline must be established within the strictly controlled boundaries of the AWS Academy Learner Lab environment.

The foundational infrastructure must satisfy:
1. **Security Isolation & Sandbox Conformance**: Dissect the pre-assigned `LabRole`, establish an explicit boundary between permitted runtime operations and sandbox-prohibited privileged operations (IAM role/policy creation), and deliver non-deployable IAM specifications as verifiable IaC code.
2. **Network Topology & Partitioning**: Construct an isolated VPC network with dual Availability Zone (AZ) redundancy, separating public ingress subnets from strictly private data plane subnets.
3. **FinOps & Resource Quota Feasibility**: Ensure infrastructure sizing respects AWS Academy hard constraints ($100 budget ceiling, single-digit vCPU quotas) without unbudgeted runaway costs (e.g., avoiding managed NAT Gateways).
4. **Declarative Reproducibility**: Prove complete lifecycle independence—the entire environment must be constructible, destructible, and reconstructible strictly through Infrastructure as Code (IaC) without manual console intervention (Zero ClickOps).

---

## 2. Scope & Technical Requirements

### 2.1 In Scope
- **IAM Dissection**: Inspecting `LabRole` via AWS CLI / Policy Simulator; documenting explicit Allow vs. Deny actions.
- **IAM Specification in IaC**: Defining a custom Read-Only IAM policy and an assumable IAM role in Terraform, capturing sandbox denial mechanics.
- **VPC Network Architecture**:
  - 1 × VPC with DNS resolution enabled (`10.0.0.0/16`).
  - 2 × Public Subnets across 2 AZs (`10.0.1.0/24`, `10.0.2.0/24`) with an Internet Gateway (IGW) and public route table.
  - 2 × Private Subnets across 2 AZs (`10.0.11.0/24`, `10.0.12.0/24`) for future M2 shards, configured as isolated internal subnets.
  - Baseline Security Groups for intra-VPC communication.
- **Service Quotas & FinOps Budgeting**: Quantifying EC2 vCPU, VPC, and EIP limits; projecting M2 operational costs (2 shards + 1 coordinator) against the $100 ceiling.
- **Recreatability Verification**: Validating teardown and re-provisioning duration and documenting failure modes.

### 2.2 Out of Scope (Deferred to Future Milestones)
- Compute instance provisioning (EC2 coordinator, shard instances, container nodes) — *Milestone 2*.
- Storage engine implementation, partitioning, and hashing ring — *Milestone 2*.
- Cross-replica event log streaming and quorum coordinator logic — *Milestone 3*.
- Metrics collection, tracing, and AI Model Context Protocol (MCP) server — *Milestone 4*.
- Autoscaling policies and dynamic shard rebalancing — *Milestone 5*.

---

## 3. Architecture Overview & Invariants

```
                                  VPC: 10.0.0.0/16 (us-east-1)
 ┌─────────────────────────────────────────────────────────────────────────────────────────────┐
 │                                                                                             │
 │   Internet Gateway (IGW)                                                                    │
 │   ▲                                                                                         │
 │   │ Route: 0.0.0.0/0 -> IGW                                                                 │
 │   ├─────────────────────────────────────────┬───────────────────────────────────────────┐   │
 │   │ Public Subnet AZ-A                      │ Public Subnet AZ-B                        │   │
 │   │ 10.0.1.0/24 (us-east-1a)                │ 10.0.2.0/24 (us-east-1b)                  │   │
 │   │ [Coordinator / Future ALB / Bastion]    │ [Coordinator Backup / Future ALB]         │   │
 │   └─────────────────────────────────────────┴───────────────────────────────────────────┘   │
 │                                                                                             │
 │   Internal Route Table: Local only (10.0.0.0/16) - Zero NAT Gateway (FinOps Safe)           │
 │   ├─────────────────────────────────────────┬───────────────────────────────────────────┐   │
 │   │ Private Subnet AZ-A                     │ Private Subnet AZ-B                       │   │
 │   │ 10.0.11.0/24 (us-east-1a)               │ 10.0.12.0/24 (us-east-1b)                 │   │
 │   │ [Shard 1 (Primary / Replica)]           │ [Shard 2 (Primary / Replica)]             │   │
 │   └─────────────────────────────────────────┴───────────────────────────────────────────┘   │
 └─────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Architectural Invariants
1. **Zero External Mutation to Private Subnets**: Private subnets must have no direct default route to an Internet Gateway (`0.0.0.0/0 -> IGW`).
2. **FinOps Defense Invariant**: No managed AWS NAT Gateways are provisioned. Outbound internet egress for private shards is denied; intra-cluster communication occurs strictly over private VPC IP addresses.
3. **Multi-AZ Availability**: All network layers span at least two discrete Availability Zones (`us-east-1a` and `us-east-1b`) to eliminate physical single points of failure (SPOF) for future shard replication.
4. **Decoupled Stack Boundaries**: Network state is completely decoupled from application compute and sandbox-restricted IAM specifications.

---

## 4. Key Architectural Decisions (ADR References)

This proposal is governed by three mandatory Architecture Decision Records:
- **`ADR-001`**: Choice of Infrastructure as Code Tool (`docs/adr/ADR-001-iac-tool.md`) -> **Terraform**.
- **`ADR-002`**: Infrastructure Stack Layout & Boundary Decoupling (`docs/adr/ADR-002-stack-layout.md`) -> **Layered Stacks (`infra/network` and `infra/iam-spec`)**.
- **`ADR-003`**: VPC CIDR Addressing Scheme & Subnet Topology (`docs/adr/ADR-003-cidr-addressing.md`) -> **`10.0.0.0/16` with dual-AZ `/24` subnets and Isolated Private Subnets**.

---

## 5. Acceptance & Verification Criteria

| ID | Criterion | Verification Method |
|---|---|---|
| **AC-1** | `LabRole` permissions dissected and cataloged. | Execution of `aws iam list-attached-role-policies` and Policy Simulator; documented in `docs/labrole-dissection.md`. |
| **AC-2** | Read-Only IAM Policy & Assumable Role defined in IaC. | Static verification via `terraform validate` in `infra/iam-spec`; simulation of deployment failure demonstrating sandbox restriction. |
| **AC-3** | VPC and Subnets provisioned via declarative IaC. | Successful execution of `terraform apply` in `infra/network`; subnets tagged and attached to route tables. |
| **AC-4** | Routing isolation verified. | Public subnets route `0.0.0.0/0` to IGW; private subnets contain only local VPC routing (`10.0.0.0/16 -> local`). |
| **AC-5** | Service quotas and M2 budget projected. | CLI quota audit and comprehensive pricing model in `docs/quotas-and-finops.md` proving monthly cost < $26. |
| **AC-6** | Recreatability proven. | Automated teardown (`terraform destroy`) and clean rebuild (`terraform apply`) with recorded cycle duration. |
| **AC-7** | AI architectural review documented. | Minimum 3 critique items evaluated with technical acceptance/refutation arguments in `docs/ai-critique.md`. |

---

## 6. Implementation Sequence

1. Write and commit OpenSpec and ADRs 001–003 (spec before code).
2. Execute automated `LabRole` and Quotas discovery scripts against AWS Academy.
3. Author Terraform code for `infra/network` and `infra/iam-spec`.
4. Deploy and verify network topology via AWS CLI.
5. Perform destruction and recreation test, measuring execution duration.
6. Generate AI Design Critique and author oral defense preparation dossier.
