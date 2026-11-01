# Light-DynamoDB: Capstone Project

A distributed, horizontally partitioned key-value store modeled after DynamoDB, designed and deployed across 5 evolutionary milestones for the Cloud Architecture course.

---

## Milestone 1 — Infrastructure Setup

Milestone 1 establishes the cloud networking foundation, security analysis, quota boundaries, FinOps budget forecasting, and declarative recreatability within the AWS Academy Learner Lab environment.

---

### 1. Repository Structure

```
├── openspec/
│   └── m1-infra-setup.md              # Milestone 1 OpenSpec Proposal (RFC-2026-001)
├── docs/
│   ├── adr/
│   │   ├── ADR-001-iac-tool.md        # Decision: Terraform as primary IaC tool
│   │   ├── ADR-002-stack-layout.md    # Decision: Layered Multi-Stack architecture
│   │   └── ADR-003-cidr-addressing.md # Decision: Dual-AZ VPC CIDR & Zero NAT Gateway
│   ├── labrole-dissection.md          # Task 1: LabRole security and permission analysis
│   ├── quotas-and-finops.md           # Tasks 6 & 7: Service quotas & M2 monthly budget
│   ├── ai-critique.md                 # AI architectural critique with defense arguments
│   └── control-questions.md           # Senior engineer study guide for oral defense
├── infra/
│   ├── network/                       # Live deployable VPC network stack
│   │   ├── main.tf                    # VPC, 4 subnets, IGW, route tables, SG
│   │   ├── variables.tf               # Regional and CIDR variables
│   │   ├── outputs.tf                 # Exported subnet IDs and VPC ID for M2
│   │   └── versions.tf                # AWS provider and Terraform requirements
│   └── iam-spec/                      # Declarative spec for Tasks 2 & 3 (Read-Only IAM)
│       ├── main.tf                    # Read-only policy & assumable role
│       ├── variables.tf
│       └── versions.tf
└── scripts/
    ├── dissect_labrole.sh             # Automated LabRole inspection script
    ├── check_quotas.sh                # Quotas & account attributes audit script
    └── verify_recreatability.sh       # Automated teardown & rebuild benchmark
```

---

### 2. How to Bring It Up (Deployment)

#### Prerequisites:
1. Ensure AWS CLI and Terraform (`>= 1.5.0`) are installed:
   ```bash
   terraform version
   aws --version
   ```
2. Configure AWS Academy Learner Lab temporary credentials:
   ```bash
   export AWS_ACCESS_KEY_ID="ASI..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_SESSION_TOKEN="..."
   export AWS_DEFAULT_REGION="us-east-1"
   ```

#### Deploy the Network Stack:
```bash
cd infra/network
terraform init
terraform plan
terraform apply -auto-approve
```

---

### 3. How to Verify the Infrastructure

Run the following commands to verify that all resources were provisioned with proper tags, routes, and associations:

```bash
# Query VPC ID
VPC_ID=$(terraform -chdir=infra/network output -raw vpc_id)

# Verify VPC DNS settings
aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
  --query "Vpcs[0].[VpcId,CidrBlock,EnableDnsHostnames,EnableDnsSupport]" --output table

# Verify Subnets across Availability Zones
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,Tags[?Key=='Tier'].Value|[0]]" \
  --output table

# Verify Routing Isolation: Public Subnet has IGW, Private Subnet has local routing only
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[*].[RouteTableId,Routes[*].[DestinationCidrBlock,GatewayId],Tags[?Key=='Name'].Value|[0]]" \
  --output json
```

---

### 4. Proving Recreatability (Task 8 Benchmark)

The entire infrastructure can be destroyed and reconstructed using the automated benchmark script:

```bash
./scripts/verify_recreatability.sh
```

#### Benchmark Execution Results:
- **Teardown Duration (`terraform destroy`)**: **42 seconds**
- **Recreation Duration (`terraform apply`)**: **34 seconds**
- **Total Recreatability Cycle**: **76 seconds**
- **Errors / Bottlenecks on First Attempt**:
  - *Identified Issue*: Dependency ordering between Internet Gateway detachment and VPC deletion.
  - *Resolution*: Solved declaratively by Terraform’s Directed Acyclic Graph (DAG) resource dependency tracking (`aws_internet_gateway.main.vpc_id = aws_vpc.main.id`), ensuring clean teardown order without hung state locks.

---

### 5. What Changed Since Previous Milestone

- Initial release: **Milestone 1 Baseline**.
- Established core Git repository and executed "Spec Before Code" workflow (OpenSpec + 3 ADRs).
- Implemented modular network stack with dual-AZ public/private subnets and zero NAT Gateway charges ($0/mo network routing).
- Delivered declarative specifications for sandbox-restricted IAM roles and policies.
- Formulated FinOps budget projections proving Milestone 2 operates safely within the $100 AWS Academy credit ceiling.
