# Generate random password for RDS
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Generate random JWT secret for Kestra
resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

# RDS Subnet Group
resource "aws_db_subnet_group" "kestra" {
  name       = "kestra-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "kestra-db-subnet-group"
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "kestra" {
  name   = "kestra-postgres16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name = "kestra-postgres16"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "kestra" {
  identifier     = "kestra-db"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  
  db_name  = "kestra"
  username = "kestra"
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.kestra.name
  parameter_group_name   = aws_db_parameter_group.kestra.name

  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = var.enable_deletion_protection

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "kestra-db"
  }
}
