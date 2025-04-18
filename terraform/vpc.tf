// Main AWS resources to make simple setup K8s in Single-AZ with Public access

locals {
  base_name   = "k8s-selfhosted"
  vpc_cidr    = "10.0.0.0/16"
  subnet_cidr = "10.0.1.0/24"
}

resource "aws_vpc" "main" {
  assign_generated_ipv6_cidr_block     = true
  cidr_block                           = local.vpc_cidr
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = true

  tags = {
    Name       = "${local.base_name}-vpc"
    Created-By = "Terraform"
    Owner      = "slazarev" //TODO: REPLACEME
  }
}

resource "aws_subnet" "public" {
  availability_zone       = "eu-west-1a"
  cidr_block              = local.subnet_cidr
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = {
    Name       = "${local.base_name}-subnet-az-a"
    Created-By = "Terraform"
    Owner      = "slazarev" //TODO: REPLACEME
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name       = "${local.base_name}-igw"
    Created-By = "Terraform"
    Owner      = "slazarev" //TODO: REPLACEME
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name       = "${local.base_name}-rt-public"
    Created-By = "Terraform"
    Owner      = "slazarev" //TODO: REPLACEME
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "main" {
  name        = "${local.base_name}-sg"
  description = "Security group for ${local.base_name}"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow all traffic from VPC CIDR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr]
  }

  ingress {
    description = "Allow SSH from designated IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["124.120.193.254/32"] //TODO: REPLACEME
  }

  ingress {
    description = "Allow Kubernetes API server traffic from designated IPs"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["124.120.193.254/32"] //TODO: REPLACEME
  }

  ingress {
    description = "Allow ICMP traffic from from VPC CIDR"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "${local.base_name}-sg"
    Created-By = "Terraform"
    Owner      = "slazarev" //TODO: REPLACEME
  }
}

resource "aws_security_group" "ingress" {
  name        = "${local.base_name}-ingress-sg"
  description = "Security group for ${local.base_name}"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow all traffic from VPC CIDR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr]
  }

  ingress {
    description = "Allow SSH from designated IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["124.120.193.254/32"] //TODO: REPLACEME
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HAproxy web monitoring traffic from designated IPs"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["124.120.193.254/32"] //TODO: REPLACEME
  }

  ingress {
    description = "Allow ICMP traffic from VPC CIDR"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "${local.base_name}-ingress-sg"
    Created-By = "Terraform"
    Owner      = "slazarev" //TODO: REPLACEME
  }
}
