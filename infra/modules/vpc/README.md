# Terraform AWS VPC Module

This module provisions a production-ready VPC in AWS with public and private subnets, NAT gateways, route tables, and a security group for SSH access.

## Features

- Creates a VPC with configurable CIDR
- Public and private subnets across multiple Availability Zones
- Internet Gateway
- Optional NAT Gateway for outbound internet access
- Route tables and subnet associations
- SSH security group for bastion access
- Fully taggable resources

## Architecture
```
VPC
├── Internet Gateway
├── Public Subnets
│ └── Route to Internet Gateway
├── Private Subnets
│ └── Route to NAT Gateway (optional)
└── SSH Security Group
```

## Usage

Example usage:

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name = "popcorn"
  environment  = "production"

  vpc_cidr = "10.0.0.0/16"

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  availability_zones = ["us-east-1a", "us-east-1b"]

  enable_nat_gateway = true

  tags = {
    Environment = "production"
    Project     = "popcorn"
  }
}
```
## Inputs
| Name                 | Description                  | Type         | Required |
| -------------------- | ---------------------------- | ------------ | -------- |
| project_name         | Project name                 | string       | yes      |
| environment          | Environment name             | string       | yes      |
| vpc_cidr             | CIDR block for VPC           | string       | yes      |
| public_subnet_cidrs  | List of public subnet CIDRs  | list(string) | yes      |
| private_subnet_cidrs | List of private subnet CIDRs | list(string) | yes      |
| availability_zones   | List of AZs                  | list(string) | yes      |
| enable_nat_gateway   | Enable NAT Gateway           | bool         | no       |
| ssh_cidr_blocks      | CIDRs allowed for SSH        | list(string) | no       |
| tags                 | Resource tags                | map(string)  | no       |

## Outputs
| Name                  | Description        |
| --------------------- | ------------------ |
| vpc_id                | VPC ID             |
| vpc_cidr_block        | VPC CIDR           |
| public_subnet_ids     | Public subnet IDs  |
| private_subnet_ids    | Private subnet IDs |
| nat_gateway_ids       | NAT gateway IDs    |
| ssh_security_group_id | SSH security group |

## Tests
Terraform module tests are available under:
```
modules/vpc/tests/
```
Run tests using:
```
terraform test
```
## Requirements
* Terraform >= 1.5
* AWS Provider ~> 5.0

## Maintainers
DevOps Team
