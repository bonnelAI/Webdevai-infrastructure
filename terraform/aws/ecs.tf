# ECS Cluster
resource "aws_ecs_cluster" "kestra" {
  name = "kestra-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "kestra-cluster"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "kestra" {
  family                   = "kestra"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "kestra"
      image     = "${aws_ecr_repository.kestra.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      command = ["server", "standalone", "--config", "/app/config/application-aws.yaml"]

      environment = [
        {
          name  = "PORT"
          value = "8080"
        },
        {
          name  = "KESTRA_CONFIGURATION"
          value = "/app/config/application-aws.yaml"
        },
        {
          name  = "KESTRA_DB_HOST"
          value = aws_db_instance.kestra.address
        },
        {
          name  = "KESTRA_DB_PORT"
          value = "5432"
        },
        {
          name  = "KESTRA_DB_NAME"
          value = "kestra"
        },
        {
          name  = "KESTRA_DB_USER"
          value = "kestra"
        }
      ]

      secrets = [
        {
          name      = "KESTRA_DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        },
        {
          name      = "KESTRA_JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_kestra.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "kestra-task-definition"
  }
}

# ECS Service
resource "aws_ecs_service" "kestra" {
  name            = "kestra-service"
  cluster         = aws_ecs_cluster.kestra.id
  task_definition = aws_ecs_task_definition.kestra.arn
  desired_count   = var.kestra_desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.kestra.arn
    container_name   = "kestra"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.kestra,
    aws_iam_role_policy.ecs_secrets_policy
  ]

  tags = {
    Name = "kestra-ecs-service"
  }
}
