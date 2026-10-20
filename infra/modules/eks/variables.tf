# EKS Module Variables

# Basic Configuration
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (staging, production)"
  type        = string
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID where EKS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for load balancers (optional)"
  type        = list(string)
  default     = []
}

# Cluster Settings
variable "cluster_version" {
  description = "Kubernetes version (EKS allows only one minor version bump per control-plane upgrade)"
  type        = string
  default     = "1.35"
}

variable "node_group_version" {
  description = "Kubernetes version for managed node groups. Use to stage node upgrades one minor at a time; if null, uses cluster_version."
  type        = string
  default     = null
  nullable    = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API endpoint (recommended: true)"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API endpoint (set false for max security)"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "IPs that can access the API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "Control plane logs to send to CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "cluster_log_retention_days" {
  description = "How long to keep CloudWatch logs"
  type        = number
  default     = 30
}

variable "cluster_encryption_key_arn" {
  description = "KMS key for secrets encryption (creates one if not specified)"
  type        = string
  default     = null
}

# Worker Nodes
variable "node_group_desired_size" {
  description = "How many nodes to run normally"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum nodes during scale-up"
  type        = number
  default     = 4
}

variable "node_group_min_size" {
  description = "Minimum nodes (for cost savings during low traffic)"
  type        = number
  default     = 1
}

variable "node_group_instance_types" {
  description = "EC2 instance types (t3.medium for staging, t3.large for prod)"
  type        = list(string)
  default     = ["g4dn.xlarge"]
}

variable "node_group_capacity_type" {
  description = "ON_DEMAND (stable) or SPOT (cheaper but can be interrupted)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_group_disk_size" {
  description = "Disk size in GB for each node"
  type        = number
  default     = 50
}

variable "create_main_node_group" {
  description = "Whether to create the Terraform-managed 'main' node group. Set to false when compute is managed outside Terraform (e.g. ad-hoc AWS-CLI-managed groups like popcorn-gpu-ng, popcorn-cpu-ng, popcorn-cpu-az1-ng)."
  type        = bool
  default     = true
}

variable "node_group_ami_type" {
  description = "AMI type for the primary node group. Set to null to let AWS choose the default for the selected instance types."
  type        = string
  default     = null
}

variable "node_group_labels" {
  description = "Kubernetes labels for nodes"
  type        = map(string)
  default     = {}
}

variable "node_group_taints" {
  description = "Kubernetes taints (for dedicated workloads)"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "node_groups" {
  description = "Additional named managed node groups, keyed by an arbitrary map key used only for the Terraform resource address (e.g. terraform import). Independent of the single 'main'/'db' node groups above."
  type = map(object({
    node_group_name = string
    instance_types  = list(string)
    capacity_type   = optional(string, "ON_DEMAND")
    ami_type        = string
    disk_size       = number
    subnet_ids      = list(string)
    labels          = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    min_size     = number
    max_size     = number
    desired_size = number
  }))
  default = {}
}

# Add-ons (versions auto-selected if null)
variable "vpc_cni_addon_version" {
  description = "VPC CNI version (leave null for latest compatible)"
  type        = string
  default     = null
}

variable "coredns_addon_version" {
  description = "CoreDNS version (leave null for latest compatible)"
  type        = string
  default     = null
}

variable "kube_proxy_addon_version" {
  description = "kube-proxy version (leave null for latest compatible)"
  type        = string
  default     = null
}

variable "enable_ebs_csi_driver" {
  description = "Install EBS CSI driver for persistent volumes"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_addon_version" {
  description = "EBS CSI driver version (leave null for latest compatible)"
  type        = string
  default     = null
}

# Access Control
variable "admin_users" {
  description = "IAM user ARNs with full cluster access (for DevOps team)"
  type        = list(string)
  default     = []
}

variable "developer_users" {
  description = "IAM user ARNs with read access (for developers)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

# ----------------------------
# DB (CPU) node group variables
# ----------------------------

variable "db_node_group_instance_types" {
  description = "Instance types for DB (CPU) node group"
  type        = list(string)
}

variable "db_node_group_desired_size" {
  description = "Desired size for DB node group"
  type        = number
}

variable "db_node_group_min_size" {
  description = "Minimum size for DB node group"
  type        = number
}

variable "db_node_group_max_size" {
  description = "Maximum size for DB node group"
  type        = number
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

#variable "vpc_id" {
#  type = string
#}
