# main.tf

# Specify the AWS provider and region
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "my-project-vpc"
  }
}

# 2. Create an Internet Gateway
resource "aws_internet_gateway" "my_gw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my-project-igw"
  }
}

# 3. Create a Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

# 4. Create a Private Subnet (Not used in this lab, but good to have)
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  tags = {
    Name = "private-subnet"
  }
}

# 5. Create a Route Table for the Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_gw.id
  }
  tags = {
    Name = "public-route-table"
  }
}

# 6. Associate the Public Subnet with the Public Route Table
resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 7. Create a Security Group for the EC2 instance
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-security-group"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-security-group"
  }
}

# 8. Create a Key Pair for SSH access
resource "aws_key_pair" "my_key_pair" {
  key_name   = "my-ec2-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1OzssOTJ9dD14SsrmlXuVegkXzm20ChJBkBgNM42XMjmbAIhkRE6cd2DQWCplsG0EucgI62rV/g7/MfsJr8+KD4cm6yl6k53H0HtHI+ni25xfBm+poEh5hs3TEkmdY+RJU1mgTMeeJijvoQIo/1UhF0/LSv4L390VVrlB8JA97OWeDHaazpPYrV/wnZZXmOVBD933o/cWbs9JmlkXvJlQfTOTeyALE4JJdL7/ELFmVVlREe/CmzptqsqLvdji2j1ogVCwDyXgoFrryHytIYjxpwNaNw5DT6ztgnRa45m+C5kj9QW15ritvk9Ju7GqmE2ClFMBStqEx8uuefkdyGoP" # <-- REPLACE WITH YOUR PUBLIC KEY
}

# 9. Provision the EC2 Instance
resource "aws_instance" "nginx_server" {
  ami           = "ami-0b09ffb6d8b58ca91" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = aws_key_pair.my_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  associate_public_ip_address = true
  
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras install nginx1 -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              EOF

  tags = {
    Name = "nginx-web-server"
  }
}