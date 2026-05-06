output "public_ips" {
  value = module.ec2_workers.public_ips
}

output "private_ips" {
  value = module.ec2_workers.private_ips
}

output "instance_ids" {
  value = module.ec2_workers.instance_ids
}

output "instance_names" {
  value = module.ec2_workers.instance_names
}
