variable "namespace" {
  description = "Namespace for monitoring "
  type        = string
  default     = "monitoring"
}
variable "prometheus_chart_version" {
  description = "Prometheus Helm chart version (override when pinning to an approved/tested release)."
  type        = string
  default     = "55.0.0"
}

variable "loki_chart_version" {
  description = "Loki chart version"
  type        = string
  default     = "2.10.1"
}

variable "helm_timeout" {
  description = "Helm wait timeout (seconds). kube-prometheus-stack on EKS often exceeds 20 minutes."
  type        = number
  default     = 3600
}

variable "node_selector" {
  description = "Optional nodeSelector for Prometheus, Grafana, and Loki. Leave empty {} to schedule on any node (required when no dedicated pool has workload=monitoring)."
  type        = map(string)
  default     = {}
}

variable "kube_prometheus_disable_admission_webhooks" {
  description = "When true, disables operator admission webhooks and operator TLS (/cert volume) so installs do not require the admission Secret."
  type        = bool
  default     = true
}

variable "storage_iops" {
  description = "EBS IOPS"
  type        = string
  default     = "3000"
}
variable "storage_type" {
  description = "EBS volume type used by monitoring persistent volumes."
  type        = string
  default     = "gp3"
}
variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "20Gi"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "15d"
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

variable "grafana_username" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_storage_size" {
  description = "Grafana storage size"
  type        = string
  default     = "5Gi"
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

variable "grafana_service_type" {
  description = "Grafana service type"
  type        = string
  default     = "ClusterIP"
}

variable "loki_storage_size" {
  description = "Loki storage size"
  type        = string
  default     = "20Gi"
}

variable "loki_retention" {
  description = "Loki data retention period"
  type        = string
  default     = "30d"
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

variable "node_exporter_cpu_request" {
  description = "Node Exporter CPU request"
  type        = string
  default     = "50m"
}

variable "node_exporter_memory_request" {
  description = "Node Exporter memory request"
  type        = string
  default     = "64Mi"
}

variable "node_exporter_cpu_limit" {
  description = "Node Exporter CPU limit"
  type        = string
  default     = "100m"
}

variable "node_exporter_memory_limit" {
  description = "Node Exporter memory limit"
  type        = string
  default     = "128Mi"
}

variable "kube_state_metrics_cpu_request" {
  description = "Kube State Metrics CPU request"
  type        = string
  default     = "50m"
}

variable "kube_state_metrics_memory_request" {
  description = "Kube State Metrics memory request"
  type        = string
  default     = "64Mi"
}

variable "kube_state_metrics_cpu_limit" {
  description = "Kube State Metrics CPU limit"
  type        = string
  default     = "100m"
}

variable "kube_state_metrics_memory_limit" {
  description = "Kube State Metrics memory limit"
  type        = string
  default     = "128Mi"
}

variable "promtail_cpu_request" {
  description = "Promtail CPU request"
  type        = string
  default     = "50m"
}

variable "promtail_memory_request" {
  description = "Promtail memory request"
  type        = string
  default     = "64Mi"
}

variable "promtail_cpu_limit" {
  description = "Promtail CPU limit"
  type        = string
  default     = "100m"
}

variable "promtail_memory_limit" {
  description = "Promtail memory limit"
  type        = string
  default     = "128Mi"
}

variable "promtail_tolerations" {
  description = "Optional tolerations for promtail pods (e.g. to reach tainted GPU nodes so backend/embedding logs get collected)."
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = optional(string)
  }))
  default = []
}

variable "enable_alertmanager" {
  description = "Enable Alertmanager"
  type        = bool
  default     = false
}

variable "enable_dcgm_exporter" {
  description = "Install NVIDIA dcgm-exporter for GPU metrics."
  type        = bool
  default     = true
}

variable "dcgm_exporter_chart_version" {
  description = "dcgm-exporter Helm chart version."
  type        = string
  default     = "4.8.3"
}

variable "prometheus_release_label" {
  description = "Release label used by ServiceMonitors to target kube-prometheus-stack."
  type        = string
  default     = "prometheus"
}

variable "dcgm_node_selector" {
  description = "Node selector for dcgm-exporter pods. Keep this limited to GPU nodes."
  type        = map(string)
  default = {
    "nvidia.com/gpu.present" = "true"
  }
}

variable "dcgm_tolerations" {
  description = "Optional tolerations for dcgm-exporter pods."
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = optional(string)
  }))
  default = []
}

variable "enable_gpu_dashboard" {
  description = "Provision the shared GPU Grafana dashboard."
  type        = bool
  default     = true
}

variable "gpu_dashboard_default_namespace" {
  description = "Default app namespace selected in the GPU dashboard."
  type        = string
  default     = "default"
}

variable "test_mode" {
  description = "Disable helm/k8s resources during terraform test"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name, used in the Loki S3 bucket and IAM role names"
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "AWS region, used to build the Loki S3 bucket URI"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider (for the Loki S3 IRSA trust policy)"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS cluster OIDC issuer URL without the https:// prefix (for the Loki S3 IRSA trust policy)"
  type        = string
}

variable "loki_s3_lifecycle_days" {
  description = "Backstop S3 lifecycle expiration for Loki objects, in case the compactor's own retention ever falls behind"
  type        = number
  default     = 14
}

variable "thanos_s3_lifecycle_days" {
  description = "S3 lifecycle expiration for Thanos blocks (no compactor/downsampling is deployed, so this is the only retention control)"
  type        = number
  default     = 30
}