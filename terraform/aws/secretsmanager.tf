# AWS Secrets Manager - Database Password
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "kestra/db-password"
  description             = "RDS PostgreSQL master password for Kestra"
  recovery_window_in_days = 7

  tags = {
    Name = "kestra-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# AWS Secrets Manager - JWT Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "kestra/jwt-secret"
  description             = "Kestra JWT signing secret"
  recovery_window_in_days = 7

  tags = {
    Name = "kestra-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}
