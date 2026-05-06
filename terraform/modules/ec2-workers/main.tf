locals {
  common_tags = {
    Project    = var.project_name
    ManagedBy  = "terraform"
    Monitoring = var.monitoring_enabled ? "enabled" : "disabled"
  }
}

data "aws_security_group" "selected" {
  id     = var.security_group_id
  vpc_id = var.vpc_id
}

resource "aws_instance" "node" {
  for_each = var.nodes

  ami                    = var.ami_id
  instance_type          = coalesce(each.value.instance_type, var.instance_type)
  key_name               = var.key_name
  vpc_security_group_ids = [data.aws_security_group.selected.id]

  tags = merge(local.common_tags, var.extra_tags, {
    Name = each.key
  })
}

resource "local_file" "ansible_inventory" {
  filename = var.ansible_inventory_path

  content = join("\n", concat(
    ["[web]"],
    [
      for name, instance in aws_instance.node :
      "${name} ansible_host=${instance.private_ip} ansible_user=${var.ansible_user} ansible_ssh_private_key_file=${var.ansible_private_key_file} ansible_python_interpreter=${var.ansible_python_interpreter}"
    ]
  ))
}
