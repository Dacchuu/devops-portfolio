# Bastion Host Module

Terraform module for an **SSH bastion (jump host)** in a public subnet. It provisions a security group, IAM role/instance profile, optional key pair, and an EC2 instance. **Bootstrap** is handled by `user_data.sh` (installed automatically on the instance; you do not run it manually on your laptop).

## Components

- EC2 instance (Amazon Linux 2023 by default, configurable AMI filter)
- Security group (SSH ingress from allowed CIDRs)
- IAM role and instance profile (minimal EC2/SSM-related permissions as defined in the module)
- Optional Elastic IP
- Optional `aws_key_pair` when `create_key_pair` is true

## Quick Start Guide

Minimal steps to use this module from an environment stack (for example `environments/staging/bastion` or a VPC stack that includes bastion).

### Prerequisites

- Terraform `>= 1.5`
- AWS credentials configured (`aws configure` or environment variables) with permission to create the resources above
- A VPC and **public subnet** ID (deploy VPC first, or pass outputs from a `terraform_remote_state` data source)

### Steps

1. **Wire the module** in your root module (example variables shown; adjust paths and values):

   ```hcl
   module "bastion" {
     source = "../../modules/bastion"

     project_name            = "popcorn"
     environment             = "staging"
     vpc_id                  = module.vpc.vpc_id
     public_subnet_id        = module.vpc.public_subnet_ids[0]
     bastion_ssh_cidr_blocks = ["203.0.113.10/32"] # your office or VPN egress
     devops_ssh_keys         = var.devops_ssh_keys
     create_key_pair         = false
     existing_key_name       = "your-keypair-name"
     tags                    = local.common_tags
   }
   ```

2. **Initialize and apply** from that stack’s directory:

   ```bash
   cd environments/<env>/bastion   # or your VPC path if bastion is combined
   terraform init
   terraform plan
   terraform apply
   ```

3. **SSH to the bastion** after apply:

   - Use the **`bastion_ssh_command`** output, or  
   - `ssh -i /path/to/private-key.pem ec2-user@<bastion_public_ip>`  
   (use `bastion_public_ip` or `bastion_eip` output if you need the address).

4. **Optional:** If you use a new key pair via `create_key_pair = true`, ensure `public_key_path` points to your public key file before apply.

### Notes

- Restrict **`bastion_ssh_cidr_blocks`** to known IPs; avoid `0.0.0.0/0` in production.
- The **`user_data.sh`** script runs **once at instance boot** on the EC2 host; it is not a separate script you execute locally.

## Usage

Example:

```hcl
module "bastion" {
  source = "../../modules/bastion"

  project_name            = local.project_name
  environment             = local.environment
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  instance_type           = "t3.small"
  volume_size             = 30
  bastion_ssh_cidr_blocks = var.bastion_ssh_cidr_blocks
  create_key_pair         = false
  existing_key_name       = var.key_pair_name
  devops_ssh_keys         = var.devops_ssh_keys
  allocate_eip            = true

  tags = local.common_tags
}
```

See `variables.tf` for the full set of inputs and defaults.

## Outputs

| Name | Description |
| ---- | ----------- |
| `bastion_instance_id` | EC2 instance ID |
| `bastion_public_ip` | Instance public IP |
| `bastion_eip` | Elastic IP when `allocate_eip` is true |
| `bastion_ssh_command` | Example SSH command |
| `bastion_security_group_id` | Bastion security group ID |

## Requirements

- Terraform `>= 1.5`
- AWS provider `~> 5.0`

## Maintainers

DevOps Team
