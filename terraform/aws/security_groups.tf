# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "kestra-alb-sg"
  description = "Security group for Kestra ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "kestra-alb-sg"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs" {
  name        = "kestra-ecs-sg"
  description = "Security group for Kestra ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "kestra-ecs-sg"
  }
}

# ALB Ingress Rule - HTTP from internet
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# ALB Egress Rule - To ECS tasks
resource "aws_security_group_rule" "alb_egress_ecs" {
  type                     = "egress"
  description              = "To ECS tasks"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  security_group_id        = aws_security_group.alb.id
}

# ECS Ingress Rule - From ALB
resource "aws_security_group_rule" "ecs_ingress_alb" {
  type                     = "ingress"
  description              = "From ALB"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs.id
}

# ECS Egress Rule - All outbound traffic
resource "aws_security_group_rule" "ecs_egress_all" {
  type              = "egress"
  description       = "All outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "kestra-rds-sg"
  description = "Security group for Kestra RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "kestra-rds-sg"
  }
}
