# Kubernetes Monitoring Module

This Terraform module installs a full Kubernetes monitoring stack using Helm.

## Components

The module deploys:

- Prometheus
- Grafana
- Loki
- Promtail
- Node Exporter
- kube-state-metrics

## Features

- Monitoring namespace creation
- Persistent storage for metrics
- Grafana dashboards
- Loki log aggregation
- Resource limit configuration

## Architecture
```
Kubernetes Cluster
└── monitoring namespace
├── Prometheus
├── Grafana
├── Loki
├── Promtail
└── Node Exporter
```

## Quick Start Guide

Minimal steps to deploy this module after your EKS cluster exists and `kubectl`/Helm access is available from Terraform.

### Prerequisites

- Terraform `>= 1.5`
- AWS credentials with access to the target account/region
- An **existing EKS cluster** (deploy VPC and EKS first)
- Kubernetes and Helm providers configured in the **root module** that calls this module (see your `environments/<env>/monitoring` stack)

### Steps

1. **Call the module** from your monitoring stack and set required inputs (at minimum `grafana_password` and storage/sizing as needed).

2. **From that stack’s directory**, run:

   ```bash
   cd environments/<env>/monitoring
   terraform init
   terraform plan
   terraform apply
   ```

3. **Verify:** Use module outputs (or `kubectl get pods -n <namespace>`) to confirm Prometheus, Grafana, and Loki are running.

4. **Optional:** With `test_mode = true`, Helm releases are skipped (used for `terraform test` only); use `false` for a real deployment.

### Notes

- Chart versions and resource sizes are inputs; tune per environment in `terraform.tfvars` or variables.
- This module does not replace cluster-level RBAC or ingress; configure those in the cluster separately if needed.

## Usage

Example:

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  namespace = "monitoring"

  # Example values only - tune per environment/workload.
  prometheus_storage_size = "20Gi"
  grafana_storage_size    = "5Gi"

  grafana_username = "admin"
  grafana_password = var.grafana_password
}
```

## Inputs

| Name                    | Description            |
| ----------------------- | ---------------------- |
| namespace               | Kubernetes namespace   |
| grafana_username        | Grafana admin username |
| grafana_password        | Grafana admin password |
| prometheus_storage_size | Prometheus storage     |
| grafana_storage_size    | Grafana storage        |
| loki_storage_size       | Loki storage           |

## Outputs

| Name           | Description            |
| -------------- | ---------------------- |
| namespace      | Monitoring namespace   |
| prometheus_url | Prometheus service URL |
| grafana_url    | Grafana service URL    |
| loki_url       | Loki service URL       |

## Requirements

* Kubernetes Provider
* Helm Provider
* Terraform >= 1.5

Maintainers
```
DevOps Team
```

---

# 📁 Final Repo Structure
```hcl
popcorn-infrastructure
│
├── modules
│ ├── vpc
│ │ ├── README.md
│ │ └── ...
│ │
│ ├── eks
│ │ ├── README.md
│ │ └── ...
│ │
│ └── monitoring
│ ├── README.md
│ └── ...
│
└── environments
```