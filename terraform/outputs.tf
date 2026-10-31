output "bastion_public_ip" {
  description = "Only public IPv4 in the lab."
  value       = aws_instance.bastion.public_ip
}

output "inventory" {
  description = "Checkpoint 02: instance IDs and private IPs."
  value = {
    ewb-bastion = { id = aws_instance.bastion.id, private_ip = aws_instance.bastion.private_ip, public_ip = aws_instance.bastion.public_ip }
    ewb-app-a   = { id = aws_instance.app_a.id, private_ip = aws_instance.app_a.private_ip, public_ip = aws_instance.app_a.public_ip }
    ewb-app-b   = { id = aws_instance.app_b.id, private_ip = aws_instance.app_b.private_ip, public_ip = aws_instance.app_b.public_ip }
  }
}

output "network_ids" {
  description = "Record these in the report inventory."
  value = {
    vpc_a            = aws_vpc.a.id
    vpc_b            = aws_vpc.b.id
    subnet_a_public  = aws_subnet.a_public.id
    subnet_a_private = aws_subnet.a_private.id
    subnet_b_private = aws_subnet.b_private.id
    igw_a            = aws_internet_gateway.a.id
    rt_a_public      = aws_route_table.a_public.id
    rt_a_private     = aws_route_table.a_private.id
    rt_b_private     = aws_route_table.b_private.id
    sg_bastion       = aws_security_group.bastion.id
    sg_app_a         = aws_security_group.app_a.id
    sg_app_b         = aws_security_group.app_b.id
    peering          = one(aws_vpc_peering_connection.a_b[*].id)
  }
}
