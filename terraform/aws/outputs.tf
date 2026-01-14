# Infrastructure Outputs

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.kestra.dns_name
}

output "kestra_url" {
  description = "URL to access Kestra UI"
  value       = "http://${aws_lb.kestra.dns_name}"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.kestra.endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL for Kestra images"
  value       = aws_ecr_repository.kestra.repository_url
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.kestra.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.kestra.name
}

output "db_password_secret_arn" {
  description = "ARN of the database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
  sensitive   = true
}
