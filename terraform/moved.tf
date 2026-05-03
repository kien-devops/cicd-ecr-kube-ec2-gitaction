moved {
  from = aws_instance.node
  to   = module.ec2_workers.aws_instance.node
}

moved {
  from = local_file.ansible_inventory
  to   = module.ec2_workers.local_file.ansible_inventory
}
