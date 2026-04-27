output "public_ips" {
  value = {
    for name, instance in aws_instance.node :
    name => instance.public_ip
  }
}

output "private_ips" {
  value = {
    for name, instance in aws_instance.node :
    name => instance.private_ip
  }
}

output "instance_ids" {
  value = {
    for name, instance in aws_instance.node :
    name => instance.id
  }
}

output "instance_names" {
  value = keys(var.nodes)
}
