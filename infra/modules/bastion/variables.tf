# Bastion module variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for bastion"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_name_filter" {
  description = "AMI name filter used to pick the bastion AMI (aws_ami data source)."
  type        = string
  default     = "al2023-ami-*-x86_64"
}

variable "root_volume_type" {
  description = "EBS root volume type for the bastion instance."
  type        = string
  default     = "gp3"
}

variable "volume_size" {
  description = "Root volume size (GB)"
  type        = number
  default     = 20
}

variable "bastion_ssh_cidr_blocks" {
  description = "CIDR blocks for bastion SSH access"
  type        = list(string)
  default     = ["192.168.1.24/32"]
}

variable "create_key_pair" {
  description = "Create new key pair"
  type        = bool
  default     = true
}

variable "existing_key_name" {
  description = "Existing key pair name"
  type        = string
  default     = null
}

variable "devops_ssh_keys" {
  description = "List of DevOps team SSH public keys"
  type        = list(string)
  default     = []
}

variable "allocate_eip" {
  description = "Allocate Elastic IP"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = null
}