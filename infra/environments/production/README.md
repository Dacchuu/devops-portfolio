# Production Environment

The production environment replicates the production infrastructure for testing and validation before releasing changes to production.

## Purpose

- Validate Terraform changes
- Test Kubernetes deployments
- Verify infrastructure updates
- Run integration testing

## Infrastructure Components

This environment provisions:

| Component | Description |
|----------|-------------|
| VPC | Production networking infrastructure |
| EKS | Production Kubernetes cluster |
| Monitoring | Observability stack for production cluster |

## Deployment Order

Provision infrastructure in the following order:
1. VPC
2. EKS
3. Monitoring


## Deployment Commands

### Deploy VPC
cd environments/production/vpc
terraform init
terraform apply

### Deploy EKS

cd environments/production/eks
terraform init
terraform apply

### Deploy Monitoring


cd environments/proudction/monitoring
terraform init
terraform apply


## Terraform State

State is stored in:
```
s3://eicon-terraform-state-bucket/environments/production/
```
## Notes

- Changes should always be validated in production before production rollout.
- Resource sizing may be smaller than production.

## Maintainers

DevOps Team