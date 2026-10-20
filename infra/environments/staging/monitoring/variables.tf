variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "popcorn-staging-eks"
}

variable "aws_region" {
  description = "AWS region for provider"
  type        = string
  default     = "us-west-1"
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

# Monitoring module inputs — values in terraform.tfvars
variable "namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "prometheus_cpu_request" {
  description = "Prometheus CPU request"
  type        = string
  default     = "200m"
}

variable "prometheus_memory_request" {
  description = "Prometheus memory request"
  type        = string
  default     = "512Mi"
}

variable "prometheus_cpu_limit" {
  description = "Prometheus CPU limit"
  type        = string
  default     = "500m"
}

variable "prometheus_memory_limit" {
  description = "Prometheus memory limit"
  type        = string
  default     = "1Gi"
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "20Gi"
}

variable "prometheus_retention" {
  description = "Prometheus data retention"
  type        = string
  default     = "7d"
}

variable "grafana_cpu_request" {
  description = "Grafana CPU request"
  type        = string
  default     = "100m"
}

variable "grafana_memory_request" {
  description = "Grafana memory request"
  type        = string
  default     = "256Mi"
}

variable "grafana_cpu_limit" {
  description = "Grafana CPU limit"
  type        = string
  default     = "200m"
}

variable "grafana_memory_limit" {
  description = "Grafana memory limit"
  type        = string
  default     = "512Mi"
}

variable "grafana_storage_size" {
  description = "Grafana storage size"
  type        = string
  default     = "5Gi"
}

variable "grafana_service_type" {
  description = "Grafana service type"
  type        = string
  default     = "LoadBalancer"
}

variable "grafana_username" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "loki_cpu_request" {
  description = "Loki CPU request"
  type        = string
  default     = "200m"
}

variable "loki_memory_request" {
  description = "Loki memory request"
  type        = string
  default     = "512Mi"
}

variable "loki_cpu_limit" {
  description = "Loki CPU limit"
  type        = string
  default     = "500m"
}

variable "loki_memory_limit" {
  description = "Loki memory limit"
  type        = string
  default     = "1Gi"
}

variable "loki_storage_size" {
  description = "Loki storage size"
  type        = string
  default     = "20Gi"
}

variable "loki_retention" {
  description = "Loki data retention"
  type        = string
  default     = "7d"
}

variable "storage_iops" {
  description = "EBS IOPS for monitoring volumes"
  type        = string
  default     = "3000"
}

variable "gpu_dashboard_default_namespace" {
  description = "Default application namespace selected in the shared GPU dashboard."
  type        = string
  default     = "popcorn-staging"
}
