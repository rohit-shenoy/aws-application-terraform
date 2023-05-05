terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "<AWS_ACCESS_KEY>"
  secret_key = "<AWS_SECRET_KEY>"
}

# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production-vpc",
    environment = "production"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "prod-gateway" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "production-gateway",
    environment = "production"
  }
}

# Create Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-gateway.id
  }

  tags = {
    Name = "production-route-table",
    environment = "production"
  }
}

# Create subnet
resource "aws_subnet" "prod-subnet" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "production-subnet",
    environment = "production"
  }
}

# Associate subnet to route table
resource "aws_route_table_association" "prod-route-table-assoc" {
  subnet_id      = aws_subnet.prod-subnet.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create security group
resource "aws_security_group" "prod-sec-group" {
  name        = "prod-webapp-security-group"
  description = "Allow prod inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "prod-webapp-security-group",
    environment = "production"
  }
}

# Create Network Interface
resource "aws_network_interface" "prod-webapp-nic" {
  subnet_id       = aws_subnet.prod-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.prod-sec-group.id]
}

# Create Elastic IP
resource "aws_eip" "prod-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.prod-webapp-nic.id
  associate_with_private_ip = "10.0.1.50"

  depends_on = [
    aws_internet_gateway.prod-gateway
  ]
}

# Create EC2 Instance
resource "aws_instance" "prod-web-server-instance" {
    ami = "ami-007855ac798b5175e"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "main-key"
    
    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.prod-webapp-nic.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y 
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
    
    tags = {
        Name = "prod-web-server"
    }
}


# Print output: public IP
output "server-public-ip" {
    value = aws_eip.prod-eip.public_ip
}

output "server-private-ip" {
    value = aws_instance.prod-web-server-instance.private_ip
}

output "server-id" {
    value = aws_instance.prod-web-server-instance.id
}



