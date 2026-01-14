variable "aws_region" {
  description = "AWS region for WordPress cloning infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for WordPress hosting"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID (will auto-select latest if not provided)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "SSH key pair name for EC2 access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into EC2 instance"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "wordpress-cloning"
}
