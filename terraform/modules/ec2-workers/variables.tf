variable "project_name" {
  description = "Project name used for common AWS tags."
  type        = string
  default     = "hospital"
}

variable "ami_id" {
  description = "AMI ID used for EC2 worker nodes."
  type        = string
}

variable "instance_type" {
  description = "Default EC2 instance type."
  type        = string
}

variable "nodes" {
  description = "Map of EC2 worker nodes to create."
  type = map(object({
    instance_type = optional(string)
  }))
}

variable "key_name" {
  description = "AWS key pair name."
  type        = string
}

variable "security_group_id" {
  description = "Existing security group ID attached to worker nodes."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID used to look up the selected security group."
  type        = string
}

variable "ansible_inventory_path" {
  description = "Path where Terraform writes the Ansible inventory file."
  type        = string
}

variable "ansible_user" {
  description = "SSH user written to the Ansible inventory."
  type        = string
  default     = "ubuntu"
}

variable "ansible_private_key_file" {
  description = "Private key path written to the Ansible inventory."
  type        = string
  default     = "./kien.pem"
}

variable "ansible_python_interpreter" {
  description = "Python interpreter path written to the Ansible inventory."
  type        = string
  default     = "/usr/bin/python3"
}

variable "monitoring_enabled" {
  description = "Whether EC2 workers should be discoverable by Prometheus EC2 service discovery."
  type        = bool
  default     = true
}

variable "extra_tags" {
  description = "Extra tags merged into every EC2 worker node."
  type        = map(string)
  default     = {}
}
