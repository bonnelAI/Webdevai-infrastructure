#!/bin/bash
set -euo pipefail

# Destroy Kestra AWS infrastructure
# WARNING: This will delete all AWS resources created by Terraform

echo "⚠️  WARNING: This will destroy all Kestra AWS infrastructure!"
echo ""
echo "This includes:"
echo "  - ECS Cluster and Tasks"
echo "  - RDS PostgreSQL Database (all data will be lost!)"
echo "  - Application Load Balancer"
echo "  - VPC, Subnets, NAT Gateway"
echo "  - ECR Repository and Docker images"
echo "  - Secrets Manager secrets"
echo ""

# Prompt for confirmation
read -p "Type 'destroy-kestra' to confirm: " CONFIRM
if [ "$CONFIRM" != "destroy-kestra" ]; then
    echo "❌ Destruction cancelled"
    exit 1
fi
echo ""

# Configuration
TERRAFORM_DIR="terraform/aws"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Change to Terraform directory
cd "$TERRAFORM_DIR"

# Run Terraform destroy
echo "🔥 Destroying infrastructure..."
terraform destroy -auto-approve
echo ""

echo "✅ Infrastructure destroyed successfully"
echo ""
echo "Note: Terraform state file remains in S3 for audit trail"
