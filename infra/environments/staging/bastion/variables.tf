# Staging Bastion variables

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "popcorn"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "bastion_instance_type" {
  description = "Bastion instance type"
  type        = string
  default     = "t3.small"
}

variable "bastion_volume_size" {
  description = "Bastion root volume size (GB)"
  type        = number
  default     = 30
}

variable "bastion_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to bastion"
  type        = list(string)
}

variable "key_pair_name" {
  description = "SSH key pair name"
  type        = string
  default     = "popcorn"
}

variable "devops_ssh_keys" {
  description = "DevOps team SSH public keys (injected into bastion)"
  type        = list(string)
}

variable "additional_tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
