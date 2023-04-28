resource "aws_instance" "example" {
    ami = "ami-0aa2b7722dc1b5612"
    instance_type = "t2.micro"
    tags = {
        Name = "terraform-example"
    }
}