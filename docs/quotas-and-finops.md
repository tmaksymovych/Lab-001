# Service Quotas & FinOps Budgeting Report (Milestone 1 — Tasks 6 & 7)

## 1. Milestone 2 Architecture Sizing Baseline

In Milestone 2, the system will scale from network setup to a functional sharded distributed store:
- **1 × Coordinator Node**: Exposes the REST API, manages the consistent hashing ring, and routes incoming requests.
- **2 × Shard Storage Nodes**: Store local partitions in memory/disk and execute CRUD operations.
- **Total Compute Nodes**: 3 instances.
- **Deployment Region**: `us-east-1` (N. Virginia).

---

## 2. Service Quotas Audit (Task 6)

The following service quotas govern our deployment within the AWS Academy Learner Lab environment:

| Service / Resource Quota | Standard Default | AWS Academy Sandbox Limit | Projected M2 Consumption | Status & Bottleneck Evaluation |
|---|---|---|:---:|---|
| **VPCs per Region** | 5 | 5 | 1 | **Safe**. Consumption: 20% of limit. |
| **Subnets per VPC** | 200 | 200 | 4 | **Safe**. 2 public + 2 private subnets. |
| **Internet Gateways per Region** | 5 | 5 | 1 | **Safe**. 1 IGW attached to `light-dynamodb-vpc`. |
| **Running On-Demand Standard (A, C, D, M, R, T, Z) Instances** | 32 vCPUs | 4 to 8 vCPUs | 6 vCPUs (3 × `t3.micro` @ 2 vCPU) | **Warning / Critical Boundary**. Standard Learner Labs cap total active vCPUs at 4 or 8 vCPUs. Sizing nodes to `t3.micro` (2 vCPU each) consumes 6 vCPUs, remaining strictly within the 8 vCPU ceiling. |
| **Elastic IP Addresses (EIP)** | 5 | 5 | 0 to 1 | **Safe**. Nodes in private subnets do not require public EIPs. |
| **EBS Volume Storage (gp3)** | 300 TB | 100 GB | 30 GB (3 × 10 GB) | **Safe**. 30% of typical sandbox volume capacity. |

> **Key Takeaway for Defense**: The primary infrastructure bottleneck in AWS Academy is the **vCPU quota on running EC2 instances**. Selecting larger instance families (`t3.medium` with 2 vCPUs and more RAM or `t3.large` with 8 vCPUs) would immediately breach the regional quota and block cluster bring-up in Milestone 2.

---

## 3. FinOps Monthly Budget Model for Milestone 2 (Task 7)

The monthly operational budget is modeled assuming 24/7 continuous execution over a 30-day month (730 hours) in `us-east-1`.

### 3.1 Itemized Cost Estimation

| Resource Component | Specifications | Unit Rate (us-east-1) | Quantity / Usage | Monthly Cost (USD) |
|---|---|---|:---:|---:|
| **Coordinator Compute** | `t3.micro` (2 vCPU, 1 GB RAM, Burstable) | $0.0104 / hour | 1 instance × 730 hrs | **$7.59** |
| **Shard 1 Compute** | `t3.micro` (2 vCPU, 1 GB RAM, Burstable) | $0.0104 / hour | 1 instance × 730 hrs | **$7.59** |
| **Shard 2 Compute** | `t3.micro` (2 vCPU, 1 GB RAM, Burstable) | $0.0104 / hour | 1 instance × 730 hrs | **$7.59** |
| **EBS Storage** | General Purpose SSD (`gp3`), Root volumes | $0.08 / GB-month | 3 × 10 GB = 30 GB | **$2.40** |
| **VPC Infrastructure** | VPC, 4 Subnets, Route Tables, IGW | $0.00 | 1 VPC stack | **$0.00** |
| **Data Transfer (Intra-VPC)** | Inter-AZ cross-traffic between Coordinator & Shards | $0.01 / GB | ~15 GB benchmark traffic | **$0.15** |
| **Public IPv4 Address** | In-use public IPv4 on Coordinator node | $0.005 / hour | 1 IPv4 × 730 hrs | **$3.65** |
| **Total Projected Cost (24/7 continuous)** | | | | **$28.97 / month** |

---

## 4. Sandbox Credit Ceiling Comparison & Burn-Rate Strategy

### Credit Cap Comparison:
- **AWS Academy Learner Lab Lifetime Credit Ceiling**: **$100.00** (or $50.00 in restricted cohorts).
- **Projected Continuous M2 Burn Rate**: **$28.97 / month** (representing ~29.0% of the $100 ceiling over an entire month).

### FinOps Optimization Strategy (Cloud Financial Management CF-2):
1. **Zero NAT Gateway Policy (Savings: ~$32.40/mo per AZ)**:
   - If a managed NAT Gateway were provisioned in each AZ, hourly gateway fees ($0.045/hr × 730 × 2 = $65.70/mo) would increase total monthly spend to **$94.67/month**, exhausting the credit pool in ~31 days even with zero benchmark traffic.
   - Eliminating the NAT Gateway guarantees financial viability throughout all five milestones.
2. **Scheduled Teardown / Stop Protocol**:
   - During active development and benchmarking, instances are run on-demand for ~2 hours per session.
   - 3 × `t3.micro` running for 20 total active development hours = $0.0312 × 20 = **$0.62 total compute cost**.
   - Stopping compute nodes between milestones reduces monthly consumption from $28.97 to **<$5.00 total**, leaving >95% of the sandbox budget intact for Milestones 3, 4, and 5.
