# Production Bastion
# Deploy after VPC. Reads VPC state and deploys bastion host

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket        = "popcorn-terraform-state-bucket"
    key           = "environments/production/vpc/terraform.tfstate"
    region        = var.aws_region
    use_lockfile  = true
  }
}

provider "aws" {
  region = var.aws_region
}

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

module "bastion" {
  source = "../../../modules/bastion"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet_id        = data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]
  instance_type           = var.bastion_instance_type
  volume_size             = var.bastion_volume_size
  bastion_ssh_cidr_blocks = var.bastion_ssh_cidr_blocks
  create_key_pair         = false
  existing_key_name       = var.key_pair_name
  devops_ssh_keys         = var.devops_ssh_keys
  allocate_eip            = true

  tags = local.common_tags
}
