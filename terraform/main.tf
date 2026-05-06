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

module "ec2_workers" {
  source = "./modules/ec2-workers"

  project_name           = var.project_name
  ami_id                 = var.ami_id
  instance_type          = var.instance_type
  nodes                  = var.nodes
  key_name               = var.key_name
  security_group_id      = var.security_group_id
  vpc_id                 = var.vpc_id
  ansible_inventory_path = var.ansible_inventory_path
}
