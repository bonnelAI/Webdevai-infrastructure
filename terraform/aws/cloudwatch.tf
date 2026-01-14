# CloudWatch Log Group for ECS Task logs
resource "aws_cloudwatch_log_group" "ecs_kestra" {
  name              = "/ecs/kestra"
  retention_in_days = 7
  kms_key_id        = null # Uses AWS managed key

  tags = {
    Name = "kestra-ecs-logs"
  }
}
