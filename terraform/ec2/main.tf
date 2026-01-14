terraform {
  required_version = ">= 1.14.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Purpose     = "wordpress-cloning-service"
    }
  }
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get default VPC (using existing VPC from Kestra deployment)
data "aws_vpc" "default" {
  default = false
  tags = {
    Name = "kestra-vpc"
  }
}

# Get public subnets from Kestra VPC
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  tags = {
    Type = "public"
  }
}

# Security Group for WordPress EC2 instance
resource "aws_security_group" "wordpress_host" {
  name        = "wordpress-cloning-host-sg"
  description = "Security group for WordPress cloning EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # HTTP access
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-cloning-host-sg"
  }
}

# IAM role for EC2 instance (SSM access + Secrets Manager)
resource "aws_iam_role" "wordpress_host" {
  name = "wordpress-cloning-host-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "wordpress-cloning-host-role"
  }
}

# Attach SSM managed instance policy
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.wordpress_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Policy for Secrets Manager access
resource "aws_iam_role_policy" "secrets_access" {
  name = "wordpress-secrets-access"
  role = aws_iam_role.wordpress_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:wordpress/*"
      }
    ]
  })
}

# Policy for RDS access
resource "aws_iam_role_policy" "rds_access" {
  name = "wordpress-rds-access"
  role = aws_iam_role.wordpress_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "wordpress_host" {
  name = "wordpress-cloning-host-profile"
  role = aws_iam_role.wordpress_host.name

  tags = {
    Name = "wordpress-cloning-host-profile"
  }
}

# Elastic IP for stable DNS
resource "aws_eip" "wordpress_host" {
  domain = "vpc"

  tags = {
    Name = "wordpress-cloning-host-eip"
  }
}

# EC2 Instance
resource "aws_instance" "wordpress_host" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.public.ids[0]
  vpc_security_group_ids = [aws_security_group.wordpress_host.id]
  iam_instance_profile   = aws_iam_instance_profile.wordpress_host.name

  root_block_device {
    volume_size           = 30 # GB
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # Basic setup will be done by setup-ec2.sh script
              echo "WordPress Cloning Host initialized at $(date)" > /var/log/wordpress-init.log
              EOF

  tags = {
    Name = "wordpress-cloning-host"
  }

  lifecycle {
    ignore_changes = [ami] # Allow manual AMI updates
  }
}

# Associate Elastic IP with instance
resource "aws_eip_association" "wordpress_host" {
  instance_id   = aws_instance.wordpress_host.id
  allocation_id = aws_eip.wordpress_host.id
}
