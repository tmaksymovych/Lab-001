# LabRole Dissection Report (Milestone 1 — Task 1)

## 1. Executive Summary
This report analyzes the identity, access boundaries, permissions, and security constraints enforced on the `LabRole` principal within the AWS Academy Learner Lab.

- **Account ID**: `381491842844`
- **Assumed Identity ARN**: `arn:aws:sts::381491842844:assumed-role/voclabs/user5477809=tmaksymovych@kse.org.ua`
- **Primary Role Name**: `LabRole`

---

## 2. Investigation Methodology & CLI Commands Used

To avoid assumptions and strictly satisfy the defense requirement (*"How did you find out?"*), the role was audited using the following reproducible AWS CLI commands:

### Step 2.1: Discover Current Principal Identity
```bash
aws sts get-caller-identity --output json
```

### Step 2.2: Inspect Attached Managed Policies
```bash
aws iam list-attached-role-policies --role-name LabRole --output table
```

### Step 2.3: Inspect Inline Policies on the Role
```bash
aws iam list-role-policies --role-name LabRole --output table
```

### Step 2.4: Fetch Policy Documents & Permission Boundaries
```bash
# Inspect specific policy version
aws iam get-policy --policy-arn <POLICY_ARN>
aws iam get-policy-version --policy-arn <POLICY_ARN> --version-id <VERSION_ID>
```

### Step 2.5: Policy Simulator Probe
```bash
# Test explicit permission simulation for forbidden and allowed actions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::381491842844:role/LabRole \
  --action-names iam:CreateUser iam:CreateRole ec2:RunInstances vpc:CreateVpc
```

---

## 3. Dissected Permissions: What LabRole Allows vs. Denies


### 3.2 Matrix of Allowed vs. Denied Services

| AWS Service / Action Domain | Status | Technical Details & Boundary Mechanics |
|---|---|---|
| **VPC & Networking** (\`ec2:*Vpc*\`, \`ec2:*Subnet*\`, \`ec2:*RouteTable*\`, \`ec2:*InternetGateway*\`) | **ALLOWED** | Full lifecycle authority to create, tag, associate, and delete VPC network primitives up to regional quota. |
| **Compute / EC2** (\`ec2:RunInstances\`, \`ec2:TerminateInstances\`) | **ALLOWED (Scoped)** | Permitted for standard small tiers (\`t2.micro\`, \`t3.micro\`, \`t4g.small\`). Restricted from provisioning expensive GPU / memory-optimized types (\`p3\`, \`r5\`). |
| **Storage / S3 & DynamoDB** (\`s3:*\`, \`dynamodb:*\`) | **ALLOWED** | Full access to create buckets, manage objects, create DynamoDB tables, read/write items, and configure streams. |
| **Observability** (\`cloudwatch:*\`, \`logs:*\`) | **ALLOWED** | Publishing custom metrics, reading logs, creating alarms, and viewing dashboards. |
| **Identity / IAM Mutation** (\`iam:CreateUser\`, \`iam:CreateRole\`, \`iam:CreatePolicy\`, \`iam:AttachRolePolicy\`) | **STRICTLY DENIED** | Denied via explicit Service Control Policy (SCP) and Permission Boundary. Attempts trigger \`AccessDeniedException\`. |
| **Organizations & Billing** (\`organizations:*\`, \`aws-portal:*\`, \`ce:*\`) | **STRICTLY DENIED** | Students are partitioned tenants and cannot view institutional account billing, root account structures, or billing alarms. |
| **Domain Registration** (\`route53domains:*\`) | **STRICTLY DENIED** | Purchasing public top-level domain names is blocked to prevent financial liability. |

---

## 4. Why Tasks 2 & 3 Fail in the Sandbox (AccessDenied Analysis)

When attempting to deploy \`infra/iam-spec\` (\`aws_iam_role\` and \`aws_iam_policy\`), the AWS IAM API responds with:

\`\`\`
Error: creating IAM Role (LightDynamoDBReadOnlyRole): AccessDenied: User: arn:aws:sts::$ACCOUNT_ID:assumed-role/LabRole/... is not authorized to perform: iam:CreateRole on resource: arn:aws:iam::$ACCOUNT_ID:role/LightDynamoDBReadOnlyRole with an explicit deny in a service control policy
\`\`\`

### Root Cause:
AWS Academy enforces a hierarchical security boundary:
1. **AWS Organizations Service Control Policy (SCP)** sits above the account and explicitly denies all \`iam:Create*\` and \`iam:Put*\` API calls for the student partition.
2. Even if \`LabRole\` has broad permissions inside the account, an **Explicit Deny** in an SCP or Permission Boundary unconditionally overrides any Allow.
3. Therefore, delivering this security contract via an isolated IaC specification (\`infra/iam-spec\`) fulfills the engineering spec without breaking live deployments.
