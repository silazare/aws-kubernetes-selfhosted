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
    Owner      = "slazarev"
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
    Owner      = "slazarev"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name       = "${local.base_name}-igw"
    Created-By = "Terraform"
    Owner      = "slazarev"
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
    Owner      = "slazarev"
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
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Kubernetes API server traffic"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ICMP traffic from anywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Owner      = "slazarev"
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
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    description = "Allow HAproxy web monitoring traffic"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ICMP traffic from anywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Owner      = "slazarev"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = [
    "099720109477",
  ]
  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*",
    ]
  }
  filter {
    name = "virtualization-type"
    values = [
      "hvm",
    ]
  }
}

// Control plain - Master nodes
resource "aws_instance" "master_nodes" {
  for_each      = toset(["0"])
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.public.id
  key_name      = "slazarev"
  vpc_security_group_ids = [
    aws_security_group.main.id,
  ]

  root_block_device {
    volume_size = 32
    volume_type = "gp3"
  }

  // EC2 Cloud Init
  user_data = base64encode(join("\n", [
    "#cloud-config",
    yamlencode({
      write_files : [
        {
          path : "/root/configure_system.sh",
          content : templatefile("${path.module}/files/configure_system.sh", { node_name = "master-${each.value}" }),
          permissions : "0755",
        },
        {
          path : "/root/install_runtime.sh",
          content : file("${path.module}/files/install_runtime.sh"),
          permissions : "0755",
        },
        {
          path : "/root/master.sh",
          content : file("${path.module}/files/master.sh"),
          permissions : "0750",
        },
        {
          path : "/root/coredns.yaml",
          content : file("${path.module}/files/coredns.yaml"),
          permissions : "0644",
        },
      ],
      runcmd : [
        ["/root/configure_system.sh"],
        ["/root/install_runtime.sh"],
        ["/root/master.sh"],
      ],
    })
  ]))

  tags = {
    Name       = "${local.base_name}-master-${each.value}"
    Created-By = "Terraform"
    Owner      = "slazarev"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

// Data plain - Worker nodes
resource "aws_instance" "worker_nodes" {
  for_each      = toset(["0", "1", "2"])
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.public.id
  key_name      = "slazarev"
  vpc_security_group_ids = [
    aws_security_group.main.id,
  ]

  root_block_device {
    volume_size = 32
    volume_type = "gp3"
  }

  // EC2 Cloud Init
  user_data = base64encode(join("\n", [
    "#cloud-config",
    yamlencode({
      write_files : [
        {
          path : "/root/configure_system.sh",
          content : templatefile("${path.module}/files/configure_system.sh", { node_name = "worker-${each.value}" }),
          permissions : "0755",
        },
        {
          path : "/root/install_runtime.sh",
          content : file("${path.module}/files/install_runtime.sh"),
          permissions : "0755",
        },
      ],
      runcmd : [
        ["/root/configure_system.sh"],
        ["/root/install_runtime.sh"],
      ],
    })
  ]))

  tags = {
    Name       = "${local.base_name}-worker-${each.value}"
    Created-By = "Terraform"
    Owner      = "slazarev"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

// Ingress LB
resource "aws_instance" "haproxy_lb" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.public.id
  key_name      = "slazarev"
  vpc_security_group_ids = [
    aws_security_group.ingress.id,
  ]

  root_block_device {
    volume_size = 32
    volume_type = "gp3"
  }

  // EC2 Cloud Init
  user_data = base64encode(join("\n", [
    "#cloud-config",
    yamlencode({
      write_files : [
        {
          path : "/root/haproxy.sh",
          content : file("${path.module}/files/haproxy.sh"),
          permissions : "0755",
        },
      ],
      runcmd : [
        ["/root/haproxy.sh"],
      ],
    })
  ]))

  tags = {
    Name       = "${local.base_name}-haproxy-ingress-lb"
    Created-By = "Terraform"
    Owner      = "slazarev"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}
