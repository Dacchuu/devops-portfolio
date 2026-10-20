terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

# --------------------
# AWS Provider (INFRA REGION)
# --------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "staging"
      Project     = "popcorn"
      Component   = "monitoring"
      ManagedBy   = "terraform"
    }
  }
}

# --------------------
# Read EKS cluster details
# --------------------
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_caller_identity" "current" {}

locals {
  oidc_issuer_host  = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer_host}"
}

# --------------------
# Kubernetes / Helm — exec auth for long Helm installs (static EKS tokens expire ~15 minutes).
# --------------------
provider "kubernetes" {
  host = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(
    data.aws_eks_cluster.cluster.certificate_authority[0].data
  )

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", var.cluster_name,
      "--region", var.aws_region,
    ]
  }
}

provider "helm" {
  kubernetes = {
    host = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.cluster.certificate_authority[0].data
    )
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", var.cluster_name,
        "--region", var.aws_region,
      ]
    }
  }
}

# --------------------
# Monitoring Module
# --------------------
module "monitoring" {
  source = "../../../modules/monitoring"

  namespace = var.namespace

  prometheus_cpu_request    = var.prometheus_cpu_request
  prometheus_memory_request = var.prometheus_memory_request
  prometheus_cpu_limit      = var.prometheus_cpu_limit
  prometheus_memory_limit   = var.prometheus_memory_limit
  prometheus_storage_size   = var.prometheus_storage_size
  prometheus_retention      = var.prometheus_retention

  grafana_cpu_request    = var.grafana_cpu_request
  grafana_memory_request = var.grafana_memory_request
  grafana_cpu_limit      = var.grafana_cpu_limit
  grafana_memory_limit   = var.grafana_memory_limit
  grafana_storage_size   = var.grafana_storage_size
  grafana_service_type   = var.grafana_service_type
  grafana_username       = var.grafana_username
  grafana_password       = var.grafana_password

  loki_cpu_request    = var.loki_cpu_request
  loki_memory_request = var.loki_memory_request
  loki_cpu_limit      = var.loki_cpu_limit
  loki_memory_limit   = var.loki_memory_limit
  loki_storage_size   = var.loki_storage_size
  loki_retention      = var.loki_retention

  storage_iops = var.storage_iops

  environment       = "staging"
  aws_region        = var.aws_region
  oidc_provider_arn = local.oidc_provider_arn
  oidc_provider_url = local.oidc_issuer_host

  gpu_dashboard_default_namespace = var.gpu_dashboard_default_namespace

  # popcorn-gpu-ng carries a nvidia.com/gpu=present:NoSchedule taint (see
  # popcorn-infrastructure modules/eks) that neither chart tolerates by
  # default, so dcgm-exporter and promtail never land on the node running
  # popcorn-backend/popcorn-embedding.
  dcgm_tolerations = [
    { key = "nvidia.com/gpu", operator = "Equal", value = "present", effect = "NoSchedule" }
  ]
  promtail_tolerations = [
    { key = "nvidia.com/gpu", operator = "Equal", value = "present", effect = "NoSchedule" }
  ]
}
