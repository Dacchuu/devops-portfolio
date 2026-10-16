run "validate_monitoring_basic" {

  command = plan

  variables {
    test_mode = true
    namespace = "monitoring"

    grafana_username = "admin"
    grafana_password = "admin123"

    storage_iops = "3000"

    prometheus_chart_version = "55.5.0"
    loki_chart_version       = "2.9.0"

    helm_timeout = 600

    enable_alertmanager = true

    prometheus_storage_size = "10Gi"
    prometheus_retention    = "7d"

    prometheus_cpu_request    = "100m"
    prometheus_memory_request = "256Mi"
    prometheus_cpu_limit      = "500m"
    prometheus_memory_limit   = "512Mi"

    grafana_storage_size   = "5Gi"
    grafana_cpu_request    = "100m"
    grafana_memory_request = "256Mi"
    grafana_cpu_limit      = "500m"
    grafana_memory_limit   = "512Mi"
    grafana_service_type   = "ClusterIP"

    node_exporter_cpu_request    = "50m"
    node_exporter_memory_request = "128Mi"
    node_exporter_cpu_limit      = "200m"
    node_exporter_memory_limit   = "256Mi"

    kube_state_metrics_cpu_request    = "50m"
    kube_state_metrics_memory_request = "128Mi"
    kube_state_metrics_cpu_limit      = "200m"
    kube_state_metrics_memory_limit   = "256Mi"

    loki_storage_size   = "10Gi"
    loki_retention      = "7d"
    loki_cpu_request    = "100m"
    loki_memory_request = "256Mi"
    loki_cpu_limit      = "500m"
    loki_memory_limit   = "512Mi"

    promtail_cpu_request    = "50m"
    promtail_memory_request = "128Mi"
    promtail_cpu_limit      = "200m"
    promtail_memory_limit   = "256Mi"
  }

  # Validate namespace
  assert {
    condition     = var.test_mode == true
    error_message = "Test mode should be enabled"
  }

  assert {
    condition     = kubernetes_namespace_v1.monitoring.metadata[0].name == "monitoring"
    error_message = "Monitoring namespace not created correctly"
  }

  # Validate Prometheus helm release
  assert {
    condition     = length(helm_release.prometheus) == 0
    error_message = "Prometheus should not be created in test mode"
  }

  # Validate Loki helm release
  assert {
    condition     = length(helm_release.loki) == 0
    error_message = "Loki should not be created in test mode"
  }

}
