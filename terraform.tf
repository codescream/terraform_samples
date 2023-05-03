resource "aws_security_group" "terraform-secgrp" {
    name = "terraform-sample-secgrp"

    ingress {
        from_port = var.server-port
        to_port = var.server-port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "terraform-lb-sg" {
    name = "lb-sg"
    
    //allow inbound http requests
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // allow all outbound requests
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_launch_configuration" "launch-config" {
    image_id = "ami-0aa2b7722dc1b5612"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.terraform-secgrp.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server-port} &
                EOF

    # Required when using a launch configuration with an ASG.
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "asg" {
    launch_configuration = aws_launch_configuration.launch-config.name
    vpc_zone_identifier = data.aws_subnets.filter_subnets.ids
    target_group_arns = [aws_lb_target_group.lb-target-grp.arn]

    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    tag {
        key =   "Name"
        value   =   "terraform-asg"
        propagate_at_launch =   true
    }
}

resource "aws_lb" "load-balancer" {
    name = "terraform-lb"
    load_balancer_type = "application"
    subnets = data.aws_subnets.filter_subnets.ids
    security_groups = [aws_security_group.terraform-lb-sg.id]
}

resource "aws_lb_listener" "http-listener" {
    load_balancer_arn = aws_lb.load-balancer.arn
    port = 80
    protocol = "HTTP"

    # By default, return a simple 404 page
    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code  = 404
        }
    }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http-listener.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-target-grp.arn
  }
}

resource "aws_lb_target_group" "lb-target-grp" {
    name = "lb-target-group"
    port = var.server-port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default_vpc.id

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

data "aws_vpc" "default_vpc" {
    default = true
}

data "aws_subnets" "filter_subnets" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default_vpc.id]
    }
}

variable "server-port" {
    description = "web server port number"
    type = number
    default = "8080"
}

output "alb_dns_name" {
    value = aws_lb.load-balancer.dns_name
    description = "load balance dns name"
}