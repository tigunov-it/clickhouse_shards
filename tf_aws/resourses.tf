resource "aws_spot_instance_request" "clickhouse" {
#  ami                         = "ami-0f122bc12c5fd6da8" // Alma Linux 8 (RedHat family)
  ami                         = "ami-064087b8d355e9051" // Ubuntu Server 22.04
  count                       = length(var.devs)
  instance_type               = "t3.medium"
  vpc_security_group_ids      = [aws_security_group.clickhouse.id]
  key_name                    = var.aws_key_name
  subnet_id                   = aws_subnet.public-subnet-1.id
  associate_public_ip_address = true
  tags                        = {
    "Name" = "clickhouse"
  }
  root_block_device {
    volume_size = 30
    tags = {
      Name = "clickhouse"
    }
  }
  depends_on = [aws_vpc.clickhouse, aws_subnet.public-subnet-1]
}

resource "aws_vpc" "clickhouse" {
  cidr_block           = "10.8.8.0/24"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags                 = {
    Name = "clickhouse"
  }
}

resource "aws_internet_gateway" "internet-gateway-clickhouse" {
  vpc_id = aws_vpc.clickhouse.id
  tags   = {
    Name = "internet_gateway_clickhouse"
  }
}

resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = aws_vpc.clickhouse.id
  cidr_block              = "10.8.8.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
  tags                    = {
    Name = "clickhouse-public-subnet-1"
  }
}

resource "aws_route_table" "public-route-table-clickhouse" {
  vpc_id = aws_vpc.clickhouse.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway-clickhouse.id
  }
  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public-subnet-1-route-table-association-clickhouse" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route-table-clickhouse.id
}

resource "aws_security_group" "clickhouse" {
  vpc_id      = aws_vpc.clickhouse.id
  name        = "allow_ssh_from_my_ip_for_clickhouse"
  description = "Allow ssh from from my ips"

  dynamic "ingress" {
    for_each = var.allow_ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.client_ip_address[0], var.client_ip_address[1], var.client_ip_address[2]]
    }
  }

  ingress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["10.8.8.0/24"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_from_my_ips"
  }
}

locals {
  ips = aws_spot_instance_request.clickhouse.*.public_ip
}

resource "local_file" "inventory" {
  content = templatefile("./templates/inventory.tfpl", {
    host_names = aws_spot_instance_request.clickhouse.*.public_ip
  })
  filename   = ".././ansible/hosts_aws.yaml"
  depends_on = [aws_spot_instance_request.clickhouse]
}
