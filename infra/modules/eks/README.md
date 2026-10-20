# Terraform AWS EKS Module

This module provisions an AWS Elastic Kubernetes Service (EKS) cluster along with managed node groups.

## Features

- Creates EKS cluster
- Managed node groups
- Optional DB node group
- IAM roles for nodes
- Kubernetes version configuration
- Control plane access configuration
- EBS CSI driver enablement

## Architecture
```
EKS Cluster
├── Control Plane
├── Worker Node Group
└── Optional DB Node Group
```

## Usage

Example:

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name = "popcorn"
  environment  = "production"

  # Required inputs — set per environment
  cluster_name = "popcorn-production"
  region       = "us-east-1"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_version = "1.35"

  # Example sizing only — these are input variables and should be set per environment/workload.
  # A common baseline is min=2 across AZs for availability, with max sized for expected peak.
  node_group_desired_size = 2
  node_group_min_size     = 2
  node_group_max_size     = 4

  # Example instance type — this is an input variable and should be set per workload requirements.
  node_group_instance_types = ["t3.medium"]

  enable_ebs_csi_driver = true
}
```
## Inputs

| Name                    | Description        | Type         |
| ----------------------- | ------------------ | ------------ |
| project_name            | Project name       | string       |
| environment             | Environment name   | string       |
| cluster_name            | EKS cluster name   | string       |
| region                  | AWS region         | string       |
| vpc_id                  | VPC ID             | string       |
| private_subnet_ids      | Private subnet IDs | list(string) |
| cluster_version         | Kubernetes version | string       |
| node_group_desired_size | Node count         | number       |
| node_group_min_size     | Min nodes          | number       |
| node_group_max_size     | Max nodes          | number       |

## Outputs

| Name              | Description        |
| ----------------- | ------------------ |
| cluster_name      | EKS cluster name   |
| cluster_endpoint  | API endpoint       |
| cluster_version   | Kubernetes version |
| node_role_arn     | Node IAM role      |
| oidc_provider_arn | OIDC provider      |

## Tests

Located at:
```
modules/eks/tests/
```
Run tests:
```
terraform test
```
### Requirements

* Terraform >= 1.5
* AWS Provider ~> 5.0
* TLS Provider

## Maintainers

DevOps Team
