#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " AWS Service Quotas & Account Attributes Audit (M1, Task 6)"
echo "=========================================================="

if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "ERROR: AWS credentials are not configured or expired."
    exit 1
fi

echo "--- EC2 Regional Attributes ---"
aws ec2 describe-account-attributes --attribute-names supported-platforms default-vpc vpc-max-security-groups-per-interface max-instances-per-filter --output table 2>/dev/null || echo "Account attributes query partially restricted"

echo "--- Current VPC Count ---"
aws ec2 describe-vpcs --query "length(Vpcs)" --output text

echo "--- Current Subnets Count ---"
aws ec2 describe-subnets --query "length(Subnets)" --output text

echo "--- Current Elastic IPs In Use ---"
aws ec2 describe-addresses --query "length(Addresses)" --output text
