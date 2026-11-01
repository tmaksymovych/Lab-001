# Control Questions & Oral Defense Preparation Guide (Milestone 1)

This study guide provides senior-principal-level answers for the 9 mandatory oral defense control questions for Milestone 1.

---

### Q1: *aaS — Compare cloud service models. When to use which?
- **IaaS (Infrastructure as a Service)**: AWS EC2, VPC, EBS.
  - *Responsibility*: Cloud provider manages physical data centers, hypervisors, and hardware networking. The customer manages the guest OS, runtime, networking rules, security patches, scaling, and application code.
  - *When to use*: When you need full kernel control, custom networking/storage drivers, legacy software lift-and-shift, or low-level distributed primitives (like our custom distributed key-value store shards).
- **PaaS (Platform as a Service)**: AWS Elastic Beanstalk, Heroku, Google App Engine.
  - *Responsibility*: Provider manages hardware, OS, runtime environment, and automated patching. Customer manages only application code and configuration.
  - *When to use*: Rapid web application deployment where operating system tuning is unnecessary.
- **SaaS (Software as a Service)**: Google Workspace, GitHub, Slack.
  - *Responsibility*: Provider manages the entire stack end-to-end including application features, backups, and availability. Customer only consumes the software and manages user access.
  - *When to use*: Standard business workflows (email, issue tracking, CRM) where building custom software provides no competitive advantage.
- **FaaS (Function as a Service / Serverless)**: AWS Lambda.
  - *Responsibility*: Provider manages server provisioning, concurrency scaling, cold starts, and idle resource reclamation. Customer manages discrete event-driven stateless functions.
  - *When to use*: Bursty, asynchronous workloads, event processing, webhook handlers, and glue code.

---

### Q2: Regions vs. Availability Zones (AZs)
- **Region**: A distinct geographic area in the world (e.g. `us-east-1` in N. Virginia, `eu-central-1` in Frankfurt) composed of multiple, physically isolated, and disaster-independent Availability Zones connected by low-latency private fiber.
  - *Purpose*: Data sovereignty compliance, legal jurisdiction, and geographic latency reduction for end users.
- **Availability Zone (AZ)**: One or more discrete data centers with redundant power, networking, and flood/cooling protection located within a Region (e.g. `us-east-1a`, `us-east-1b`).
  - *Purpose*: High Availability (HA) and fault tolerance within a single geographical location. A hardware failure, fire, or power outage in one AZ does not impact adjacent AZs.
  - *Design Rule*: Production systems must always span $\ge 2$ AZs to eliminate physical single points of failure (SPOF).

---

### Q3: Define Infrastructure as Code (IaC) and its value
- **Definition**: The practice of managing and provisioning computing infrastructure (networks, virtual machines, load balancers, access control) through machine-readable definition files, rather than physical hardware configuration or interactive web consoles (ClickOps).
- **Value & Core Invariants**:
  1. **Deterministic Reproducibility**: Prevents "snowflake servers" and configuration drift. Environments (Dev, Staging, Prod) are mathematically identical clones.
  2. **Auditability & Version Control**: Every change is proposed via pull requests, reviewed, and tracked in Git history with exact blame and commit attribution.
  3. **Disaster Recovery (DR)**: An entire regional infrastructure can be re-provisioned from scratch in minutes using `terraform apply` after a catastrophic outage.
  4. **Automated Testing & Blast Radius Verification**: Changes can be previewed (`terraform plan` / CloudFormation Change Sets) before applying mutations to live environments.

---

### Q4: Difference between using Roles and User Groups for assigning policies
- **IAM User Group**:
  - A collection of human IAM users.
  - Policies attached to a group grant static, persistent credentials (long-lived API access keys, console passwords) to all member users.
  - *Usage*: Managing human teams (e.g. `DevelopersGroup`, `BillingAdminsGroup`).
- **IAM Role**:
  - An identity that is not associated with a specific person or persistent credential.
  - Grants **temporary, dynamically rotated credentials** via AWS Security Token Service (STS) using the `sts:AssumeRole` API call.
  - Can be assumed by AWS services (e.g. EC2 instance profile, Lambda execution role), external identity providers (OAuth/OIDC/SAML federated SSO), or cross-account principals.
  - *Security Invariant*: Follows least privilege and eliminates hard-coded secrets or long-lived API keys.

---

### Q5: VPC CIDR block calculations and subnet mathematics
- **CIDR (Classless Inter-Domain Routing)**: Format `A.B.C.D/M`, where $M$ is the network prefix length in bits.
- **Formula for Total IP addresses**: $2^{(32 - M)}$.
  - For VPC `10.0.0.0/16`: $32 - 16 = 16$ bits $\implies 2^{16} = 65,536$ total IP addresses.
  - For Subnet `10.0.1.0/24`: $32 - 24 = 8$ bits $\implies 2^8 = 256$ total IP addresses.
- **AWS 5 Reserved IP Addresses Rule**:
  In every subnet, AWS reserves 5 IP addresses that cannot be assigned to hosts:
  1. `.0`: Network address.
  2. `.1`: Reserved by AWS for the VPC Router (default gateway).
  3. `.2`: Reserved by AWS for the DNS resolver (AmazonProvidedDNS / Route 53 Resolver).
  4. `.3`: Reserved by AWS for future internal networking capabilities.
  5. `.255`: Network broadcast address (VPC does not broadcast, but the IP is reserved).
  - *Usable host capacity for a `/24` subnet*: $256 - 5 = 251$ usable IP addresses.

---

### Q6: How to arrange public and private subnets, and how does it work?
- **Public Subnet Mechanism**:
  - An Internet Gateway (IGW) is created and attached to the VPC.
  - A Public Route Table is created with a default route: `0.0.0.0/0 -> igw-xxxxxx`.
  - The public subnets are explicitly associated with this Route Table.
  - Resources inside receive public IPv4 addresses and can initiate and receive bidirectional internet traffic.
- **Private Subnet Mechanism**:
  - Private subnets are associated with a separate Private Route Table.
  - This Route Table contains **only the local VPC route**: `10.0.0.0/16 -> local`.
  - There is **no route to an IGW**. External internet entities cannot route packets to private IP addresses.
  - Internal communication between public and private subnets works seamlessly over the local route (`10.0.0.0/16`) via the VPC router, regulated by Security Groups.

---

### Q7: When to use Allow and Deny policies?
- **AWS IAM Evaluation Logic**:
  1. **Default State**: **Implicit Deny**. By default, all requests across all services are denied unless explicitly permitted.
  2. **Explicit Allow**: Used to grant specific permissions according to the Principle of Least Privilege (e.g. `ec2:DescribeInstances` on a specific resource).
  3. **Explicit Deny**: Used for absolute guardrails, security perimeters, and Service Control Policies (SCPs).
  - **Golden Invariant**: **An Explicit Deny ALWAYS trumps an Explicit Allow**. If a policy statement allows `s3:*` but another statement or SCP contains `Effect: Deny, Action: s3:DeleteBucket`, the user can never delete a bucket under any circumstances.

---

### Q8: What does LabRole allow and deny, and how did you find out?
- **Allowed**: Standard compute and data engineering services: EC2 (burstable types like `t2`/`t3`), VPC networking lifecycle, S3 object storage, DynamoDB tables, CloudWatch metrics and alarms.
- **Denied**: Identity mutation (`iam:CreateUser`, `iam:CreateRole`, `iam:CreatePolicy`), root account billing (`aws-portal:*`, `ce:*`), AWS Organizations, and purchasing domain names.
- **How We Found Out (CLI Methodology)**:
  1. Ran `aws sts get-caller-identity` to discover the exact assumed role identity ARN.
  2. Executed `aws iam list-attached-role-policies --role-name LabRole` to inspect managed policies.
  3. Inspected specific policy statement documents with `aws iam get-policy-version`.
  4. Simulated authorization decisions using `aws iam simulate-principal-policy` against forbidden actions (`iam:CreateRole`), observing the explicit denial enforced by the environment's permission boundaries and SCPs.

---

### Q9: Change Sets and Drift Detection — What does each show, and when do you need which?
- **Change Sets (in Terraform: `terraform plan`)**:
  - *What it shows*: A declarative execution diff comparing your **local code against the current state file**. Shows what *will happen* (`+` create, `~` modify in-place, `-` destroy and recreate) if you execute an apply.
  - *When to use*: **Before applying changes**. Mandatory during code reviews and CI/CD pipelines to prevent accidental resource deletion or disruption before mutating live infrastructure.
- **Drift Detection (in Terraform: `terraform plan -refresh-only`)**:
  - *What it shows*: Compares the **current state file against actual real-world resources in AWS**. Identifies un-tracked out-of-band changes introduced by manual console actions (ClickOps), external scripts, or automated cloud provider updates.
  - *When to use*: **Continuously / Periodically**. Used to detect security tampering, unapproved manual mutations, and ensure the Git repository remains the single source of truth (SSOT).
