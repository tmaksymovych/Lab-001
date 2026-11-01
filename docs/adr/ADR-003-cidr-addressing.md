# ADR-003: VPC CIDR Addressing Scheme & Subnet Topology

## 1. Context & Problem Statement

Milestone 1 requires designing a Virtual Private Cloud (VPC) network that will host a distributed, sharded key-value store across Milestones 2 through 5. The network topology must satisfy:
- High availability across physical failure domains (Availability Zones).
- Clear traffic isolation between external public entry points (Coordinator / Load Balancer) and internal data plane nodes (Database Shards & Replicas).
- Strict adherence to the FinOps budget ceiling of the AWS Academy Learner Lab ($100 maximum total lifetime credits).
- Mathematical correctness of CIDR block allocation, accounting for AWS internal IP reservations.

---

## 2. Considered Alternatives

### Alternative 1: Single Public Subnet Architecture
- **Description**: A single public subnet where both the coordinator and all storage shards reside with public IP addresses, protected only by Security Groups.
- **Pros**: Simplest possible routing table; no complex routing or private subnets.
- **Cons**: Severe security flaw. Directly exposing database shards with public IP addresses violates least-privilege networking. No physical AZ separation (single point of failure).

### Alternative 2: Dual-AZ Public & Private Subnets with Managed NAT Gateways
- **Description**: 2 Public Subnets with an Internet Gateway (IGW) and 2 Private Subnets with AWS Managed NAT Gateways in each AZ.
- **Pros**: Shards in private subnets can initiate outbound internet requests (e.g. running `apt update` or downloading packages directly) while remaining unaddressable from the public internet.
- **Cons**: **FinOps Disaster in AWS Academy Sandbox**:
  - AWS charges ~$0.045 per hour per NAT Gateway, plus data processing fees ($0.045/GB).
  - 1 NAT Gateway = ~$32.40 / month.
  - 2 NAT Gateways (for High Availability) = **~$64.80 / month**.
  - In an AWS Academy Learner Lab with a $50 to $100 credit ceiling, provisioning NAT Gateways will burn through 65%–100% of the entire budget within 30 days while completely idle, terminating the student account before Milestone 2 can be defended!

### Alternative 3: Dual-AZ Public & Isolated Private Subnets (Zero NAT Gateway)
- **Description**:
  - VPC CIDR: `10.0.0.0/16`.
  - Dual Availability Zones: `us-east-1a` and `us-east-1b`.
  - 2 Public Subnets (`10.0.1.0/24`, `10.0.2.0/24`) attached to an Internet Gateway via a Public Route Table.
  - 2 Private Subnets (`10.0.11.0/24`, `10.0.12.0/24`) attached to a Private Route Table with **strictly local routing** (`10.0.0.0/16 -> local`). No NAT Gateways.
- **Pros**:
  - **$0.00 / month cost for routing**: Zero NAT Gateway charges, perfectly protecting the $100 budget ceiling.
  - **True Network Isolation**: Shards are completely unreachable from the public internet, and cannot leak data outbound to external IP addresses.
  - **Multi-AZ Resilience**: Satisfies the 6 Pillars of the AWS Well-Architected Framework (Reliability pillar).
  - **Expansion Headroom**: `/24` subnets provide 251 usable IPs per tier, leaving massive room across the `10.0.0.0/16` space for future tiers (e.g. monitoring, caches).
- **Cons**:
  - Private nodes cannot directly reach the public internet for OS package updates.
  - *Mitigation*: Application binaries for shards are containerized or deployed from Golden AMIs, or routed via a lightweight forward-proxy / bastion host in the public subnet if strictly necessary during build time. For AWS services (S3, DynamoDB), free Gateway VPC Endpoints can be attached with zero hourly cost.

---

## 3. Decision Outcome

**Chosen Alternative**: **Alternative 3: Dual-AZ Public & Isolated Private Subnets (Zero NAT Gateway)**.

### Rationale:
1. **Curriculum Alignment**: The course prompt specifically states: *"Public one has IGW, private ones are for internal access only."* It does not mandate NAT Gateways.
2. **FinOps Defense Invariant**: Defending our rejection of NAT Gateways based on hourly cost ($32.40/mo vs $100 credit cap) is a key demonstration of the `CF-2` (Cloud Financial Management) skill.
3. **High Availability Baseline**: Spanning `us-east-1a` and `us-east-1b` prepares the foundation for M3 replication quorums across distinct physical failure zones.

---

## 4. CIDR Addressing & IP Allocation Mathematics

### VPC Supernet:
- **CIDR**: `10.0.0.0/16`
- **Total IP space**: $2^{(32 - 16)} = 2^{16} = 65,536$ addresses.
- **Range**: `10.0.0.0` to `10.0.255.255`.

### Subnet Allocation:

| Subnet Identifier | CIDR Block | Availability Zone | Purpose | Total IPs | Usable IPs |
|---|---|---|---|:---:|:---:|
| `public-subnet-1` | `10.0.1.0/24` | `us-east-1a` | Ingress / Coordinator Node / Bastion | 256 | 251 |
| `public-subnet-2` | `10.0.2.0/24` | `us-east-1b` | Ingress / Standby Coordinator / ALB | 256 | 251 |
| `private-subnet-1`| `10.0.11.0/24`| `us-east-1a` | Data Plane / Shard 1 (Primary/Replica) | 256 | 251 |
| `private-subnet-2`| `10.0.12.0/24`| `us-east-1b` | Data Plane / Shard 2 (Primary/Replica) | 256 | 251 |
| *Reserved Space* | `10.0.20.0/24`+| Multi-AZ | Reserved for M4 telemetry & M5 caches | 64,512 | - |

### AWS Reserved IP Address Invariant:
In every subnet, AWS reserves the first 4 and the last 1 IP addresses (total 5 reserved per subnet):
Taking `10.0.1.0/24` as an example:
- `10.0.1.0`: Network address.
- `10.0.1.1`: Reserved by AWS for the VPC router.
- `10.0.1.2`: Reserved by AWS for DNS (AmazonProvidedDNS / Route 53 Resolver).
- `10.0.1.3`: Reserved by AWS for future use.
- `10.0.1.255`: Network broadcast address (VPC does not support broadcast, but address is reserved).
- **Usable Pool**: `10.0.1.4` through `10.0.1.254` = **251 usable IP addresses**.

---

## 5. Routing Table Rules

### Public Route Table (`rtb-public`):
| Destination CIDR | Target | Purpose |
|---|---|---|
| `10.0.0.0/16` | `local` | Intra-VPC private communication across all subnets and AZs |
| `0.0.0.0/0` | `igw-xxxxxx` (Internet Gateway) | Default outbound route to the public internet |

- **Subnet Associations**: `public-subnet-1`, `public-subnet-2`.

### Private Route Table (`rtb-private`):
| Destination CIDR | Target | Purpose |
|---|---|---|
| `10.0.0.0/16` | `local` | Intra-VPC private communication only |

- **Subnet Associations**: `private-subnet-1`, `private-subnet-2`.
- **Default Route (`0.0.0.0/0`)**: **None**. Traffic targeted outside the VPC is dropped.

---

## 6. Consequences

### Positive:
- Predictable, mathematically sound network layout with clean decimal alignment (`10.0.1.x`, `10.0.2.x`, `10.0.11.x`, `10.0.12.x`).
- Absolute zero ongoing cost for the networking routing layer.
- Subnets provide 251 usable host IPs each, vastly exceeding the scaling requirements of the capstone while retaining over 64,000 unallocated IPs for future expansion.

### Negative & Mitigations:
- In M2, if shard nodes require software installations at launch, they must either use AMI pre-baking, Docker images pulled through local mirrors, or temporary routing via a coordinator proxy node located in the public subnet.
