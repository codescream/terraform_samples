resource "aws_security_group" "terraform-secgrp" {
    name = "terraform-sample-secgrp"

    ingress {
        from_port = var.server-port
        to_port = var.server-port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "example" {
    ami = "ami-0aa2b7722dc1b5612"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.terraform-secgrp.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server-port} &
                EOF

    user_data_replace_on_change = true

    tags = {
        Name = "terraform-example"
    }
}

variable "server-port" {
    description = "web server port number"
    type = number
   // default = "8080"
}

output "ec2_instance_ip" {
    value = aws_instance.example.public_ip
    description = "public ip of web server"
}