// Compute resources

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
  key_name      = "slazarev" //TODO: REPLACEME
  vpc_security_group_ids = [
    aws_security_group.main.id,
  ]
  source_dest_check = false

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
    Owner      = "slazarev" //TODO: REPLACEME
  }

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}

// Data plain - Worker nodes
resource "aws_instance" "worker_nodes" {
  for_each      = toset(["0", "1", "2"])
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.public.id
  key_name      = "slazarev" //TODO: REPLACEME
  vpc_security_group_ids = [
    aws_security_group.main.id,
  ]
  source_dest_check = false

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
    ]
  }
}

// Ingress LB
resource "aws_instance" "haproxy_lb" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.public.id
  key_name      = "slazarev" //TODO: REPLACEME
  vpc_security_group_ids = [
    aws_security_group.ingress.id,
  ]
  source_dest_check = false

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
    Owner      = "slazarev" //TODO: REPLACEME
  }

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}
