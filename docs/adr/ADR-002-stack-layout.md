# ADR-002: Infrastructure Stack Layout & Boundary Decoupling

- **Status**: Accepted
- **Date**: 2026-11-02
- **Authors**: Student Engineer
- **Course**: SE470 Cloud Architecture (Capstone Milestone 1)

---

## 1. Context & Problem Statement

Milestone 1 requires provisioning foundational networking resources (VPC, subnets, route tables, internet gateways) while also delivering declarative specifications for custom Read-Only IAM policies and Assumable Roles that are intentionally rejected by the AWS Academy sandbox environment.

Furthermore, future milestones will introduce compute instances, storage volumes, replication fanout queues, telemetry pipelines, and autoscaling groups.

If all resources are bundled into a single monolithic configuration, changes to application compute or attempts to apply restricted IAM policies would threaten or block the entire network stack. We must determine how to organize the IaC code across logical boundaries to minimize blast radius and isolate sandbox restrictions.

---

## 2. Considered Alternatives

### Alternative 1: Monolithic Single-Stack Layout
- **Description**: All resources (VPC, subnets, routing, security groups, IAM specifications, and future M2 compute) reside in a single root directory with one shared `terraform.tfstate`.
- **Pros**:
  - Single invocation command (`terraform apply`).
  - No need for cross-stack data passing or remote state references.
- **Cons**:
  - **Large Blast Radius**: A mistake in compute or IAM configuration risks tearing down or corrupting the network layer.
  - **Sandbox Blocker**: Applying restricted IAM resources in the same stack will cause `terraform apply` to fail, leaving the entire deployment in a degraded state.
  - **Slow Iteration**: Every plan and apply must evaluate every resource in the system, degrading developer feedback loops in M2–M5.

### Alternative 2: Layered / Decoupled Multi-Stack Layout
- **Description**: Infrastructure is segregated into isolated layers with separate state files and directory trees:
  - `infra/network/`: The foundational, slowly changing network fabric (VPC, Subnets, IGW, Route Tables, Security Group rules).
  - `infra/iam-spec/`: The declarative specification of course-required Read-Only IAM policies and Assumable Roles (validated and simulated, but decoupled from live network provisioning).
  - `infra/compute/` (M2+): Future coordinator and shard instances consuming network outputs.
- **Pros**:
  - **Zero Blast Radius on Core Network**: Network infrastructure can be provisioned once and remain untouched during high-frequency compute deployments in M2–M5.
  - **Sandbox Isolation**: The prohibited IAM resources in `infra/iam-spec/` can be validated with `terraform validate` and simulated against AWS without interrupting or failing the core network deployment.
  - **Clear Lifecycle Alignment**: Resources with differing lifecycles (long-lived networks vs. short-lived compute nodes) are strictly separated.
- **Cons**:
  - Requires maintaining multiple state files and passing outputs (e.g. `vpc_id`, `subnet_ids`) across layers via `terraform_remote_state` or `terraform.tfvars`.

---

## 3. Decision Outcome

**Chosen Alternative**: **Alternative 2: Layered / Decoupled Multi-Stack Layout**.

### Rationale:
1. **Academic & Sandbox Compliance**: Tasks 2 & 3 explicitly require delivering IAM policies and roles in code, while acknowledging that the sandbox rejects their attachment. Isolating them into `infra/iam-spec/` allows full code inspection, syntax validation, and documented deployment simulation without polluting the working network stack.
2. **Blast Radius Control**: A database shard failure or autoscaling misconfiguration in M2–M5 cannot inadvertently delete or alter the VPC, subnets, or routing rules.
3. **Reproducibility Testing (Task 8)**: Teardown and recreation of the network stack can be benchmarked cleanly in isolation without waiting for or disrupting orthogonal application layers.

---

## 4. Directory Structure Implementation

```
SE470 Cloud architecture/
├── openspec/
│   └── m1-infra-setup.md
├── docs/
│   ├── adr/
│   │   ├── ADR-001-iac-tool.md
│   │   ├── ADR-002-stack-layout.md
│   │   └── ADR-003-cidr-addressing.md
│   ├── labrole-dissection.md
│   ├── quotas-and-finops.md
│   └── ai-critique.md
├── infra/
│   ├── network/                <-- Live deployable network layer
│   │   ├── main.tf             (VPC, Subnets, IGW, Route Tables)
│   │   ├── variables.tf        (CIDR blocks, region, tags)
│   │   ├── outputs.tf          (VPC ID, Subnet IDs for M2)
│   │   └── versions.tf         (Terraform & AWS provider requirements)
│   └── iam-spec/               <-- Course-required IAM IaC specification
│       ├── main.tf             (Read-Only Policy & Assumable Role)
│       ├── variables.tf
│       └── versions.tf
└── scripts/
    ├── dissect_labrole.sh      (Task 1 discovery script)
    ├── check_quotas.sh         (Task 6 quotas audit)
    └── verify_recreatability.sh(Task 8 benchmark script)
```

---

## 5. Consequences

### Positive:
- High degree of modularity and safety throughout the multi-milestone capstone.
- Clean separation between sandbox-permitted infrastructure and sandbox-restricted IAM models.
- Fast execution times for `terraform plan` and `apply` in the network layer.

### Negative & Mitigations:
- Downstream stacks (M2 coordinator and shards) will need to ingest the subnet IDs and VPC ID exported by `infra/network/outputs.tf`. This is solved cleanly by passing IDs via input variables or AWS CLI query data sources.
