variable "region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name used for common AWS tags."
  type        = string
  default     = "hospital"
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
}

variable "instance_type" {
  description = "Default EC2 instance type."
  type        = string
}

variable "nodes" {
  description = "Map of EC2 nodes to create"
  type = map(object({
    instance_type = optional(string)
  }))
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
}

variable "security_group_id" {
  description = "Existing security group ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ansible_inventory_path" {
  description = "Path to Ansible hosts.ini"
  type        = string
}
