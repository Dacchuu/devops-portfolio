# Production EKS Cluster

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = var.vpc_remote_state_key
    region = var.terraform_state_region
  }
}

# Locals

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "DevOps"
    Region      = var.region
    ManagedBy   = "Terraform"
  }
}

# EKS Module

module "eks" {
  source = "../../../modules/eks"

  # REQUIRED inputs (this fixes your error)
  cluster_name = var.cluster_name
  region       = var.region

  project_name = var.project_name
  environment  = var.environment

  # VPC
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnet_ids

  # Cluster config
  cluster_version                      = var.cluster_version
  node_group_version                   = var.node_group_version
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # GPU node group
  node_group_desired_size   = var.node_group_desired_size
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_instance_types = var.node_group_instance_types
  node_group_capacity_type  = var.node_group_capacity_type
  node_group_disk_size      = var.node_group_disk_size

  # DB node group
  db_node_group_instance_types = var.db_node_group_instance_types
  db_node_group_desired_size   = var.db_node_group_desired_size
  db_node_group_min_size       = var.db_node_group_min_size
  db_node_group_max_size       = var.db_node_group_max_size

  enable_ebs_csi_driver = var.enable_ebs_csi_driver

  admin_users     = var.admin_users
  developer_users = var.developer_users

  tags = merge(local.common_tags, var.additional_tags)
}
