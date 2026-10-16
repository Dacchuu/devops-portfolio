# Production VPC

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Common values
locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Owner       = "DevOps"
      Region      = var.aws_region
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )
}

# VPC
module "vpc" {
  source = "../../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr = var.vpc_cidr

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  availability_zones = var.availability_zones

  enable_nat_gateway = var.enable_nat_gateway
  ssh_cidr_blocks    = var.ssh_cidr_blocks

  tags = local.common_tags
}
