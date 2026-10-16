# Monitoring Module Outputs

output "namespace" {
  description = "Namespace name"
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "prometheus_url" {
  description = "Prometheus service URL"
  value       = "http://prometheus-prometheus.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:9090"
}

output "grafana_url" {
  description = "Grafana service URL"
  value       = "http://prometheus-grafana.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:80"
}

output "loki_url" {
  description = "Loki service URL"
  value       = "http://loki.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:3100"
}

output "access_commands" {
  description = "Port-forward commands"
  value = {
    prometheus = "kubectl port-forward -n ${kubernetes_namespace_v1.monitoring.metadata[0].name} svc/prometheus-prometheus 9090:9090"
    grafana    = "kubectl port-forward -n ${kubernetes_namespace_v1.monitoring.metadata[0].name} svc/prometheus-grafana 3000:80"
    loki       = "kubectl port-forward -n ${kubernetes_namespace_v1.monitoring.metadata[0].name} svc/loki 3100:3100"
  }
}

output "loki_s3_bucket" {
  description = "S3 bucket holding Loki chunks/index"
  value       = aws_s3_bucket.loki_logs.bucket
}

output "loki_s3_role_arn" {
  description = "IRSA role ARN Loki assumes to read/write its S3 bucket"
  value       = aws_iam_role.loki_s3.arn
}

output "thanos_s3_bucket" {
  description = "S3 bucket holding Thanos-shipped Prometheus blocks"
  value       = aws_s3_bucket.thanos_blocks.bucket
}

output "prometheus_s3_role_arn" {
  description = "IRSA role ARN Prometheus/Thanos sidecar assumes to write its S3 bucket"
  value       = aws_iam_role.prometheus_s3.arn
}

output "grafana_credentials" {
  description = "Grafana login - get password from secret"
  value = {
    username         = var.grafana_username
    password_command = "kubectl get secret grafana-credentials -n ${kubernetes_namespace_v1.monitoring.metadata[0].name} -o jsonpath='{.data.admin-password}' | base64 -d"
  }
  sensitive = true
}
