############################################
# Locals: the workbook's address plan
############################################
locals {
  common_tags = {
    Project = "EWB-VPC-Peering"
    Student = var.student_name
  }

  vpc_a_cidr     = "10.10.0.0/16"
  a_public_cidr  = "10.10.1.0/24"
  a_private_cidr = "10.10.2.0/24"
  vpc_b_cidr     = "10.20.0.0/16"
  b_private_cidr = "10.20.1.0/24"

  bastion_ip = "10.10.1.10"
  app_a_ip   = "10.10.2.10"
  app_b_ip   = "10.20.1.10"

  az = data.aws_availability_zones.available.names[0] # same AZ for the whole lab
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Amazon Linux 2023, x86_64 (workbook requirement)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

############################################
# VPC A: 10.10.0.0/16 (public + private subnet, IGW)
############################################
resource "aws_vpc" "a" {
  cidr_block = local.vpc_a_cidr
  tags       = { Name = "ewb-vpc-a" }
}

resource "aws_subnet" "a_public" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = local.a_public_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false # public IP is enabled per instance (bastion only)
  tags                    = { Name = "ewb-a-public" }
}

resource "aws_subnet" "a_private" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = local.a_private_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-a-private" }
}

resource "aws_internet_gateway" "a" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-igw-a" }
}

# ewb-rt-a-public: local (automatic) + 0.0.0.0/0 -> IGW
resource "aws_route_table" "a_public" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-rt-a-public" }
}

resource "aws_route" "a_public_internet" {
  route_table_id         = aws_route_table.a_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.a.id
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.a_public.id
  route_table_id = aws_route_table.a_public.id
}

# ewb-rt-a-private: local only (no internet route, no NAT)
resource "aws_route_table" "a_private" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-rt-a-private" }
}

resource "aws_route_table_association" "a_private" {
  subnet_id      = aws_subnet.a_private.id
  route_table_id = aws_route_table.a_private.id
}

############################################
# VPC B: 10.20.0.0/16 (private only, NO internet gateway)
############################################
resource "aws_vpc" "b" {
  cidr_block = local.vpc_b_cidr
  tags       = { Name = "ewb-vpc-b" }
}

resource "aws_subnet" "b_private" {
  vpc_id                  = aws_vpc.b.id
  cidr_block              = local.b_private_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-b-private" }
}

resource "aws_route_table" "b_private" {
  vpc_id = aws_vpc.b.id
  tags   = { Name = "ewb-rt-b-private" }
}

resource "aws_route_table_association" "b_private" {
  subnet_id      = aws_subnet.b_private.id
  route_table_id = aws_route_table.b_private.id
}

############################################
# Security groups (inbound rules from the workbook)
# Terraform removes the default allow-all egress, so it is
# declared explicitly to match the workbook's "default outbound".
############################################
resource "aws_security_group" "bastion" {
  name        = "ewb-sg-bastion"
  description = "Bastion: SSH from the student's /32 only"
  vpc_id      = aws_vpc.a.id
  tags        = { Name = "ewb-sg-bastion" }
}

resource "aws_security_group" "app_a" {
  name        = "ewb-sg-app-a"
  description = "App-A: SSH from bastion, ICMP echo from App-B"
  vpc_id      = aws_vpc.a.id
  tags        = { Name = "ewb-sg-app-a" }
}

resource "aws_security_group" "app_b" {
  name        = "ewb-sg-app-b"
  description = "App-B: SSH from bastion, ICMP echo from App-A"
  vpc_id      = aws_vpc.b.id
  tags        = { Name = "ewb-sg-app-b" }
}

# --- ewb-sg-bastion
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from my public IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.my_ip_cidr
}

# --- ewb-sg-app-a
resource "aws_vpc_security_group_ingress_rule" "app_a_ssh" {
  security_group_id = aws_security_group.app_a.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.bastion_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "app_a_icmp_from_b" {
  security_group_id = aws_security_group.app_a.id
  description       = "ICMP echo request from App-B"
  ip_protocol       = "icmp"
  from_port         = 8 # ICMP type 8 (echo request)
  to_port           = 0 # ICMP code 0
  cidr_ipv4         = "${local.app_b_ip}/32"
}

# --- ewb-sg-app-b
resource "aws_vpc_security_group_ingress_rule" "app_b_ssh" {
  security_group_id = aws_security_group.app_b.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.bastion_ip}/32"
}

# Toggled by var.app_b_icmp_enabled for the controlled failure test
resource "aws_vpc_security_group_ingress_rule" "app_b_icmp_from_a" {
  count = var.app_b_icmp_enabled ? 1 : 0

  security_group_id = aws_security_group.app_b.id
  description       = "ICMP echo request from App-A"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = "${local.app_a_ip}/32"
}

# Default outbound allow-all, declared explicitly
resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_a_all" {
  security_group_id = aws_security_group.app_a.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_b_all" {
  security_group_id = aws_security_group.app_b.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

############################################
# Peering: request (A) -> accept (B) -> routes on both sides
# Same account and Region, so auto_accept performs the "Accept request" step.
############################################
resource "aws_vpc_peering_connection" "a_b" {
  count = var.enable_peering ? 1 : 0

  vpc_id      = aws_vpc.a.id # requester
  peer_vpc_id = aws_vpc.b.id # accepter
  auto_accept = true
  tags        = { Name = "ewb-a-b-peer" }
}

# App-A -> VPC B
resource "aws_route" "a_private_to_b" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.a_private.id
  destination_cidr_block    = local.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# Return path: VPC B -> VPC A
resource "aws_route" "b_private_to_a" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.b_private.id
  destination_cidr_block    = local.vpc_a_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# Bastion (ProxyJump) -> VPC B. More specific than 0.0.0.0/0, so it wins.
resource "aws_route" "a_public_to_b" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.a_public.id
  destination_cidr_block    = local.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

############################################
# Compute: key pair + 3 instances with fixed private IPs
############################################
resource "aws_key_pair" "lab" {
  key_name   = "ewb-lab"
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.a_public.id
  private_ip                  = local.bastion_ip
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(local.common_tags, { Name = "ewb-bastion-root" })
  }

  tags       = { Name = "ewb-bastion" }
  depends_on = [aws_route.a_public_internet]
}

resource "aws_instance" "app_a" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.a_private.id
  private_ip                  = local.app_a_ip
  vpc_security_group_ids      = [aws_security_group.app_a.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(local.common_tags, { Name = "ewb-app-a-root" })
  }

  tags = { Name = "ewb-app-a" }
}

resource "aws_instance" "app_b" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.b_private.id
  private_ip                  = local.app_b_ip
  vpc_security_group_ids      = [aws_security_group.app_b.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(local.common_tags, { Name = "ewb-app-b-root" })
  }

  tags = { Name = "ewb-app-b" }
}

############################################
# Generated SSH config (same entries as workbook page 8).
# Used by Ansible and by you:  ssh -F ansible/ssh_config ewb-app-b
############################################
resource "local_file" "ssh_config" {
  filename        = "${path.module}/../ansible/ssh_config"
  file_permission = "0644"
  content         = <<-EOT
    Host ewb-bastion
        HostName ${aws_instance.bastion.public_ip}
        User ec2-user
        IdentityFile ${var.private_key_path}
        IdentitiesOnly yes
        ServerAliveInterval 30

    Host ewb-app-a
        HostName ${local.app_a_ip}
        User ec2-user
        IdentityFile ${var.private_key_path}
        IdentitiesOnly yes
        ProxyJump ewb-bastion

    Host ewb-app-b
        HostName ${local.app_b_ip}
        User ec2-user
        IdentityFile ${var.private_key_path}
        IdentitiesOnly yes
        ProxyJump ewb-bastion
  EOT
}
