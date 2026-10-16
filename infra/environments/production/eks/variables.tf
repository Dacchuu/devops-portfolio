# EKS Configuration Variables

variable "project_name" {
  description = "Project name for tagging and module inputs"
  type        = string
  default     = "eicon"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# Remote state (VPC) — configurable so this stack is not tied to hard-coded bucket/key/region
variable "terraform_state_bucket" {
  description = "S3 bucket holding Terraform state"
  type        = string
  default     = "eicon-terraform-state-bucket"
}

variable "terraform_state_region" {
  description = "AWS region where the state bucket lives (used for remote state backend config)"
  type        = string
  default     = "us-east-1"
}

variable "vpc_remote_state_key" {
  description = "Object key for the production VPC terraform.tfstate in the state bucket"
  type        = string
  default     = "environments/production/vpc/terraform.tfstate"
}

variable "cluster_version" {
  description = "EKS control plane Kubernetes version (one minor bump per apply)"
  type        = string
  default     = "1.35"
}

variable "node_group_version" {
  description = "Optional: pin main/db node group version to stage upgrades (one minor at a time). Null = same as cluster_version."
  type        = string
  default     = null
  nullable    = true
}

variable "cluster_endpoint_private_access" {
  description = "Allow kubectl from within VPC"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Allow kubectl from internet"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API (use office/VPN egress; set in environments/production/terraform.tfvars)"
  type        = list(string)
}

variable "node_group_desired_size" {
  description = "How many nodes to run normally"
  type        = number
}

variable "node_group_max_size" {
  description = "Max nodes during traffic spikes"
  type        = number
}

variable "node_group_min_size" {
  description = "Min nodes during quiet times"
  type        = number
}

variable "node_group_instance_types" {
  description = "Node instance types"
  type        = list(string)
}

variable "node_group_capacity_type" {
  description = "ON_DEMAND (stable) or SPOT (cheaper)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_group_disk_size" {
  description = "Disk per node in GB"
  type        = number
}

variable "enable_ebs_csi_driver" {
  description = "Enable persistent volumes"
  type        = bool
  default     = true
}

variable "admin_users" {
  description = "IAM ARNs with full cluster access"
  type        = list(string)
}

variable "developer_users" {
  description = "IAM ARNs with read-only access"
  type        = list(string)
  default     = []
}

variable "additional_tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}

# DB (CPU) node group variables

variable "db_node_group_instance_types" {
  type    = list(string)
  default = []
}

variable "db_node_group_desired_size" {
  type    = number
  default = 0
}

variable "db_node_group_min_size" {
  type    = number
  default = 0
}

variable "db_node_group_max_size" {
  type    = number
  default = 0
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}
