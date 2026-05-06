output "public_ips" {
  description = "Public IP addresses by worker node name."
  value = {
    for name, instance in aws_instance.node :
    name => instance.public_ip
  }
}

output "private_ips" {
  description = "Private IP addresses by worker node name."
  value = {
    for name, instance in aws_instance.node :
    name => instance.private_ip
  }
}

output "instance_ids" {
  description = "EC2 instance IDs by worker node name."
  value = {
    for name, instance in aws_instance.node :
    name => instance.id
  }
}

output "instance_names" {
  description = "Worker node names from the input map."
  value       = keys(var.nodes)
}

output "worker_iam_role_name" {
  description = "IAM role name attached to EC2 worker nodes."
  value       = aws_iam_role.worker_role.name
}

output "worker_iam_instance_profile_name" {
  description = "IAM instance profile name attached to EC2 worker nodes."
  value       = aws_iam_instance_profile.worker_profile.name
}
