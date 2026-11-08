#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../infra/network"

LOG_FILE="../../docs/recreatability-proof.log"

echo "=========================================================="
echo " Automated Recreatability Benchmark (Milestone 1, Task 8)"
echo "=========================================================="

# 1. Measure Teardown (Destroy)
echo "Step 1: Destroying existing network stack..."
START_DESTROY=$(date +%s)
terraform destroy -auto-approve
END_DESTROY=$(date +%s)
DURATION_DESTROY=$((END_DESTROY - START_DESTROY))
echo "Teardown completed in: ${DURATION_DESTROY}s"

# 2. Measure Provisioning (Apply)
echo "Step 2: Rebuilding network stack from IaC alone..."
START_APPLY=$(date +%s)
terraform apply -auto-approve
END_APPLY=$(date +%s)
DURATION_APPLY=$((END_APPLY - START_APPLY))
echo "Recreation completed in: ${DURATION_APPLY}s"

# 3. Output Verification
echo "Step 3: Querying provisioned resources..."
VPC_ID=$(terraform output -raw vpc_id)
PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)

cat << EOF | tee "$LOG_FILE"
======================================================
RECREATABILITY PROOF EXECUTION LOG
======================================================
Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Terraform Destroy Duration: ${DURATION_DESTROY} seconds
Terraform Apply Duration:   ${DURATION_APPLY} seconds
Total Recreatability Cycle: $((DURATION_DESTROY + DURATION_APPLY)) seconds

Provisioned Resources:
- VPC ID: $VPC_ID
- Public Subnets: $PUBLIC_SUBNETS
- Private Subnets: $PRIVATE_SUBNETS
- Internet Gateway ID: $(terraform output -raw internet_gateway_id)
- S3 Gateway Endpoint: $(terraform output -raw s3_endpoint_id)
- DynamoDB Gateway Endpoint: $(terraform output -raw dynamodb_endpoint_id)
- Coordinator Security Group: $(terraform output -raw coordinator_sg_id)
- Shard Security Group: $(terraform output -raw shard_sg_id)

Result: SUCCESS (Zero manual console interventions required).
======================================================
EOF

echo "Verification complete. Log saved to $LOG_FILE"
