terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.region
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

  tags = {
    Name = each.key
  }
}

resource "local_file" "ansible_inventory" {
  filename = var.ansible_inventory_path

  content = join("\n", concat(
    ["[web]"],
    [
      for name, instance in aws_instance.node :
      "${name} ansible_host=${instance.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=./kien.pem ansible_python_interpreter=/usr/bin/python3"
    ]
  ))
}
