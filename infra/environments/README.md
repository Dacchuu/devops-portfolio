# popcorn Infrastructure (Terraform)

This repository contains the Infrastructure as Code (IaC) used to provision and manage the **popcorn platform infrastructure on AWS** using **Terraform**.

The infrastructure is structured using **modular Terraform architecture**, allowing reusable modules and environment-specific configurations.

---

# Architecture Overview

The platform infrastructure consists of three major layers:

1. **Networking Layer (VPC)**
2. **Compute Layer (EKS Cluster)**
3. **Observability Layer (Monitoring Stack)**

```
AWS
├── VPC
│ ├── Public Subnets
│ ├── Private Subnets
│ ├── NAT Gateway
│ └── Bastion Host
│
├── EKS Cluster
│ ├── Control Plane
│ └── Worker Node Groups
│
└── Monitoring Stack
├── Prometheus
├── Grafana
└── Loki
```

---

# Repository Structure

```
popcorn-infrastructure
│
├── modules
│   ├── vpc
│   ├── bastion
│   ├── eks
│   └── monitoring
│
├── environments
│   ├── staging
│   │   ├── vpc
│   │   ├── eks
│   │   └── monitoring
│   │
│   └── production
│       ├── vpc
│       ├── eks
│       └── monitoring
│
├── .tflint.hcl
├── .gitignore
└── README.md
```

## Modules

Reusable Terraform modules are located in:
```
modules/
```

Each module provisions a specific infrastructure component.

| Module         | Description                                             |
| -------------- | ------------------------------------------------------- |
| **vpc**        | Creates AWS VPC, subnets, NAT gateway, and routing      |
| **bastion**    | Bastion host for secure SSH access                      |
| **eks**        | AWS EKS cluster with managed node groups                |
| **monitoring** | Kubernetes monitoring stack (Prometheus, Grafana, Loki) |

Modules are designed to be environment-agnostic and reusable.

## Environments

Environment-specific infrastructure definitions are located under:
```
environments/
```
Each environment composes modules to provision complete infrastructure.

| Environment    | Purpose                              |
| -------------- | ------------------------------------ |
| **staging**    | Testing and validation environment   |
| **production** | Live infrastructure for the platform |

## Terraform State

Terraform remote state is stored in:
```
S3 Bucket: popcorn-terraform-state-bucket
```
State structure:
```
environments/<environment>/<component>/terraform.tfstate
```
Example:
```
environments/production/vpc/terraform.tfstate
```
State locking is handled using DynamoDB.

## Infrastructure Deployment Order

Infrastructure must be deployed in the following order:
```
1. VPC
2. EKS
3. Monitoring
```
Dependencies:

* EKS requires VPC outputs
* Monitoring requires EKS cluster

## Deployment Commands

### Deploy VPC
```
cd environments/production/vpc

terraform init
terraform plan
terraform apply
```
### Deploy EKS
```
cd environments/production/eks
terraform init
terraform plan -var-file=../terraform.tfvars
terraform apply -var-file=../terraform.tfvars
```
(`../terraform.tfvars` holds environment-wide EKS settings such as `admin_users` and office CIDRs for the Kubernetes API.)
### Deploy Monitoring
```
cd environments/production/monitoring
terraform init
terraform plan
terraform apply
```
## Development Workflow

Before committing infrastructure changes, run:
```
terraform fmt -recursive
terraform validate
terraform test
tflint --recursive
```
These checks ensure:

Terraform formatting compliance
* Configuration validity
* Module test coverage
* Infrastructure linting

## Terraform Testing

Terraform module tests are located in:
```
modules/<module>/tests
```
Run tests using:
```
terraform test
```
Tests validate module behavior before deployment.

## Linting

This repository uses TFLint for Terraform linting.
Configuration file:
```
.tflint.hcl
```
Run lint checks:
```
tflint --recursive
```

## Safety Checklist Before Production Apply

Verify:

* Terraform plan output
* Resource counts
* Instance sizes
* Network CIDRs

## Important

Production infrastructure changes must be reviewed and approved before execution.

Always review the Terraform plan carefully before applying.

## Requirements
| Tool         | Version |
| ------------ | ------- |
| Terraform    | >= 1.5  |
| AWS Provider | ~> 5.0  |
| TFLint       | Latest  |

## Maintainers

DevOps Team
