# Staging environment variables

variable "project_name" {
  description = "Project name used for resource naming and tags"
  type        = string
  default     = "eicon"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

# Network
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "172.31.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["172.31.10.0/24", "172.31.11.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["172.31.20.0/24", "172.31.21.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-1a", "us-west-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "ssh_cidr_blocks" {
  description = "SSH access CIDRs"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

# Tags
variable "additional_tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}