# Application Load Balancer
resource "aws_lb" "kestra" {
  name               = "kestra-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "kestra-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "kestra" {
  name        = "kestra-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200,307"
  }

  tags = {
    Name = "kestra-target-group"
  }
}

# ALB Listener
resource "aws_lb_listener" "kestra" {
  load_balancer_arn = aws_lb.kestra.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kestra.arn
  }
}
