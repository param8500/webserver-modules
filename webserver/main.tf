data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key = var.db_remote_state_key
    region = "us-east-2"
  }
}
resource "aws_launch_configuration" "mylc" {
  image_id        = "ami-0fb653ca2d3203ac1"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.mysg.id]

  user_data = <<EOF
              #!/bin/bash
              echo "Hello, World" >> index.html
              echo "${data.terraform_remote_state.db.outputs.address}">>index.html
              echo "${data.terraform_remote_state.db.outputs.port}">>index.html
              nohup busybox httpd -f -p ${var.port} &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "myasg" {
  launch_configuration = aws_launch_configuration.mylc.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  target_group_arns    = [aws_lb_target_group.asg_tg.arn]
  health_check_type    = "ELB"
  min_size             = var.min_size
  max_size             = var.max_size
  tag {
    key                 = "Name"
    value               = "${var.environment}-web_asg"
    propagate_at_launch = true
  }

}

data "aws_vpc" "default" {
  default = true

}

data "aws_subnets" "default" {
  filter {
    name  = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

}
resource "aws_security_group" "mysg" {
name = "${var.environment}-web-sg"
}
resource "aws_security_group_rule" "web-irule" {
type = "ingress"
security_group_id = aws_security_group.mysg.id
from_port   = var.port
to_port     = var.port
protocol    = "tcp"
cidr_blocks = local.all_ips
}
resource "aws_alb" "web_alb" {
  name               = "${var.environment}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id]
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.web_alb.arn
  port = local.http_port
  protocol = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}
resource "aws_lb_listener_rule" "alb-lr" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg_tg.arn
  }
  condition {
    path_pattern {
      values = ["*"]
    }
  }
}
resource "aws_security_group" "alb_sg" {
  name = "${var.environment}-alb-sg"
}
resource "aws_security_group_rule" "in-rule" {
  type = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port   = local.http_port
  protocol    = local.tcp_protocol
  to_port     = local.http_port
  cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "ex-rule" {
  type = "egress"
  security_group_id = aws_security_group.alb_sg.id
  from_port   = local.any_port
  protocol    = local.any_protocol
  to_port     = local.any_port
  cidr_blocks = local.all_ips
}

resource "aws_lb_target_group" "asg_tg" {
  name     = "${var.environment}-webtg"
  port     = var.port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

output "alb_dnsname" {
  value = aws_alb.web_alb.dns_name

}
