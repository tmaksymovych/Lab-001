# ADR-001: Choice of Infrastructure as Code (IaC) Tool

- **Status**: Accepted
- **Date**: 2026-11-02
- **Authors**: Student Engineer
- **Course**: SE470 Cloud Architecture (Capstone Milestone 1)

---

## 1. Context & Problem Statement

To satisfy Milestone 1 requirements, all cloud infrastructure must be provisioned and managed declaratively without manual interventions in the AWS Management Console (Zero ClickOps). The project requires:
- Managing foundational network resources (VPC, Subnets, Route Tables, Gateways, Security Groups).
- Modeling future compute, replication, and telemetry resources across Milestones 2 through 5.
- Performing drift detection and reviewing proposed changes before applying them.
- Operating within the AWS Academy Learner Lab environment, which enforces strict IAM permission boundaries, lacks root access, and imposes a finite session timeout.

We must select an Infrastructure as Code (IaC) tool that provides high execution speed, deterministic plan previews, robust modularity, and alignment with course control questions.

---

## 2. Considered Alternatives

### Alternative 1: Terraform (by HashiCorp) / OpenTofu
- **Description**: An open-source, cloud-agnostic declarative IaC tool using HashiCorp Configuration Language (HCL) with a dedicated state management engine.
- **Pros**:
  - Declarative syntax with rich type checking and validation (`terraform validate`).
  - Fast local execution and API orchestration via AWS Provider.
  - Granular change previews (`terraform plan`) and drift detection (`terraform plan -refresh-only`).
  - Clear modularity (`modules/`) ideal for scaling from M1 networking to M2–M5 sharded architectures.
  - Highly decoupled from proprietary cloud consoles; state can be stored locally or in S3.
- **Cons**:
  - Requires maintaining a state file (`terraform.tfstate`). In AWS Academy, state locking via DynamoDB is restricted by IAM, requiring local state or un-locked S3 storage.

### Alternative 2: AWS CloudFormation
- **Description**: The native AWS declarative templating engine using YAML or JSON.
- **Pros**:
  - Zero external tooling or binary installation required; supported natively by the AWS CLI and Management Console.
  - AWS manages the state file internally; no local state files or manual locking required.
  - Native support for Change Sets (`aws cloudformation create-change-set`) and Stack Drift Detection (`aws cloudformation detect-stack-drift`), directly matching the terminology of Control Question #9.
- **Cons**:
  - Verbose and brittle YAML syntax with awkward parameter passing.
  - Slow feedback loop: stack rollback on syntax or permission errors can take several minutes to stabilize in AWS Academy.
  - Modularization across multiple stacks (nested stacks / cross-stack exports) is cumbersome and error-prone.

### Alternative 3: AWS Cloud Development Kit (CDK)
- **Description**: An imperative programming framework (TypeScript/Python) that synthesizes into CloudFormation templates.
- **Pros**:
  - Full power of general-purpose programming languages (loops, classes, unit tests).
- **Cons**:
  - Significant cognitive and runtime overhead (Node.js runtime, npm dependencies, synthesis step).
  - Generates opaque, multi-thousand-line CloudFormation templates that complicate debugging permission errors in the AWS Academy sandbox.
  - Heavy boilerplate for a project where network and compute primitives should remain transparent.

---

## 3. Decision Outcome

**Chosen Alternative**: **Alternative 1: Terraform** (with explicit architectural mapping to AWS CloudFormation concepts).

### Rationale:
1. **Developer Velocity & Fast Feedback**: Terraform executes resource dependency graphs locally in parallel, allowing M1 VPC creation in ~30–45 seconds and immediate teardown, compared to several minutes of CloudFormation stack polling.
2. **Modular Architecture for M2–M5**: Terraform’s module system allows us to keep the M1 network stack intact while cleanly appending coordinator modules in M2 and multi-shard replica sets in M3.
3. **Sandbox IAM Isolation**: Non-deployable sandbox resources (such as custom IAM roles in Task 2 & 3) can be validated cleanly via `terraform validate` and `terraform plan` without triggering stuck rollback states in CloudFormation.

---

## 4. Concept Mapping for Oral Defense (Control Question #9)

To ensure seamless answers during the oral defense, the operational concepts of Terraform map directly to AWS CloudFormation primitives as follows:

| Concept | AWS CloudFormation | Terraform | Purpose |
|---|---|---|---|
| **Change Preview** | **Change Set** (`aws cloudformation create-change-set`) | **Plan** (`terraform plan`) | Inspect proposed resource additions, modifications, and deletions *before* execution to prevent unintended downtime. |
| **Drift Detection** | **Stack Drift Detection** (`aws cloudformation detect-stack-drift`) | **Refresh & Drift Plan** (`terraform plan -refresh-only`) | Compare the real-world state in AWS against the declared code to identify manual out-of-band changes (ClickOps). |
| **State Storage** | AWS-managed internal database | `terraform.tfstate` (local/S3) | Maintains mapping between declared code identifiers and real AWS resource IDs (VPC IDs, Subnet IDs). |
| **Rollback Strategy**| Automatic stack rollback on failure | Transactional resource creation; halts on error and preserves state of already created resources | CloudFormation destroys failed resources automatically; Terraform keeps what succeeded and requires targeted remediation. |

---

## 5. Consequences

### Positive:
- Clean, readable HCL code organized into reusable modules.
- Immediate plan outputs showing exact diffs (`+` create, `~` update in-place, `-` destroy).
- Highly portable between local development environments and CI/CD pipelines (M2).

### Negative & Mitigations:
- **State File Protection**: Because DynamoDB state locking is restricted by AWS Academy `LabRole`, state is stored in a local `.tfstate` file backed up by Git-ignored storage and reproducible via clean recreation scripts.
- **Binary Requirement**: Terraform CLI must be available in the local Linux environment. A setup script (`scripts/setup_terraform.sh`) will be provided to download the standalone binary automatically.
