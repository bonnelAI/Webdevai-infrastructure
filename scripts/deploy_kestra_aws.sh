#!/bin/bash
set -euo pipefail

# Deploy Kestra to AWS ECS Fargate
# Correct sequence: Terraform (creates ECR) -> Build -> Push -> Deploy

echo "🚀 Deploying Kestra to AWS ECS Fargate..."
echo ""

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
TERRAFORM_DIR="terraform/aws"
PROJECT_ROOT="$(pwd)"

# Get AWS account ID
echo "📋 Getting AWS account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "   Account ID: $AWS_ACCOUNT_ID"
echo ""

# Step 1: Initialize Terraform
echo "🏗️  Step 1/5: Initializing Terraform..."
cd "$TERRAFORM_DIR"
if [ ! -d ".terraform" ]; then
    terraform init
else
    echo "   Already initialized (skipping)"
fi
echo ""

# Step 2: Apply Terraform (creates ECR repository first)
echo "🏗️  Step 2/5: Creating AWS infrastructure (including ECR)..."
echo "   This will create: VPC, ECR, RDS, ECS Cluster, ALB, etc."
terraform plan -target=aws_ecr_repository.kestra -out=tfplan-ecr
echo ""
read -p "Create ECR repository and base infrastructure? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Deployment cancelled"
    rm -f tfplan-ecr
    exit 1
fi
terraform apply tfplan-ecr
rm -f tfplan-ecr
echo ""

# Get ECR repository URL from Terraform output
ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/kestra")
echo "📦 ECR Repository: $ECR_REPO_URL"
echo ""

# Step 3: Authenticate Docker to ECR
echo "🔐 Step 3/5: Authenticating Docker to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo ""

# Step 4: Build and Push Docker image
cd "$PROJECT_ROOT"
echo "🔨 Step 4/5: Building Docker image..."
docker build \
    --platform linux/amd64 \
    -f docker/Dockerfile.kestra \
    -t kestra:latest \
    -t "${ECR_REPO_URL}:latest" \
    .
echo ""

echo "📤 Pushing image to ECR..."
docker push "${ECR_REPO_URL}:latest"
echo ""

# Step 5: Apply full Terraform configuration
cd "$TERRAFORM_DIR"
echo "🚀 Step 5/5: Deploying remaining infrastructure and ECS service..."
terraform plan -out=tfplan-full
echo ""
read -p "Deploy full infrastructure with Kestra service? (yes/no): " CONFIRM_FULL
if [ "$CONFIRM_FULL" != "yes" ]; then
    echo "❌ Deployment cancelled"
    rm -f tfplan-full
    exit 1
fi
terraform apply tfplan-full
rm -f tfplan-full
echo ""

# Get outputs
echo "✅ Deployment complete!"
echo ""
echo "📋 Infrastructure Details:"
terraform output
echo ""
echo "🌐 Access Kestra UI at:"
terraform output -raw kestra_url
echo ""
echo ""
echo "⏳ Wait 2-3 minutes for ECS task to start and health checks to pass."
echo "   Then navigate to the URL above to access Kestra."
