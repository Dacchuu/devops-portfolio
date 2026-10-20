# Monitoring Module
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

resource "kubernetes_secret_v1" "grafana_credentials" {
  metadata {
    name      = "grafana-credentials"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    admin-user     = var.grafana_username
    admin-password = var.grafana_password
  }

  type = "Opaque"
}

# ----------------------------
# Loki S3 backend — removes Loki's dependency on a single-AZ EBS volume.
# ----------------------------
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "loki_logs" {
  bucket = "popcorn-${var.environment}-loki-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "loki_logs" {
  bucket = aws_s3_bucket.loki_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "loki_logs" {
  bucket = aws_s3_bucket.loki_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    # Backstop GC in case the Loki compactor (limits_config.retention_period) ever falls behind.
    expiration {
      days = var.loki_s3_lifecycle_days
    }
  }
}

data "aws_iam_policy_document" "loki_s3_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:loki"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "loki_s3" {
  name               = "popcorn-${var.environment}-loki-s3"
  assume_role_policy = data.aws_iam_policy_document.loki_s3_assume_role.json
}

data "aws_iam_policy_document" "loki_s3" {
  statement {
    sid    = "LokiListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.loki_logs.arn]
  }

  statement {
    sid    = "LokiReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.loki_logs.arn}/*"]
  }
}

resource "aws_iam_role_policy" "loki_s3" {
  name   = "popcorn-${var.environment}-loki-s3"
  role   = aws_iam_role.loki_s3.id
  policy = data.aws_iam_policy_document.loki_s3.json
}

# ----------------------------
# Thanos sidecar S3 backend — removes Prometheus's dependency on a single-AZ
# EBS volume. Sidecar-only (no Store Gateway/Querier): local storage becomes
# ephemeral, so a Prometheus restart loses the local query window until data
# re-accumulates, but nothing is lost — Thanos has already shipped completed
# blocks to S3.
# ----------------------------
resource "aws_s3_bucket" "thanos_blocks" {
  bucket = "popcorn-${var.environment}-thanos-blocks-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "thanos_blocks" {
  bucket = aws_s3_bucket.thanos_blocks.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "thanos_blocks" {
  bucket = aws_s3_bucket.thanos_blocks.id

  rule {
    id     = "expire-old-blocks"
    status = "Enabled"

    filter {}

    # No compactor/downsampling is deployed, so blocks accumulate raw — this
    # is a backstop cap on storage growth, not a real retention policy.
    expiration {
      days = var.thanos_s3_lifecycle_days
    }
  }
}

data "aws_iam_policy_document" "prometheus_s3_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:prometheus"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "prometheus_s3" {
  name               = "popcorn-${var.environment}-prometheus-s3"
  assume_role_policy = data.aws_iam_policy_document.prometheus_s3_assume_role.json
}

data "aws_iam_policy_document" "prometheus_s3" {
  statement {
    sid    = "ThanosListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.thanos_blocks.arn]
  }

  statement {
    sid    = "ThanosReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.thanos_blocks.arn}/*"]
  }
}

resource "aws_iam_role_policy" "prometheus_s3" {
  name   = "popcorn-${var.environment}-prometheus-s3"
  role   = aws_iam_role.prometheus_s3.id
  policy = data.aws_iam_policy_document.prometheus_s3.json
}

resource "kubernetes_secret_v1" "thanos_objstore_config" {
  metadata {
    name      = "thanos-objstore-secret"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    "object-store.yaml" = yamlencode({
      type = "S3"
      config = {
        bucket   = aws_s3_bucket.thanos_blocks.bucket
        endpoint = "s3.${var.aws_region}.amazonaws.com"
        region   = var.aws_region
      }
    })
  }

  type = "Opaque"
}

# Dashboard hand-created in the Grafana UI on 2026-07-15 (not provisioned via
# code) — moved here so it survives with persistence disabled below.
resource "kubernetes_config_map_v1" "pod_logs_dashboard" {
  metadata {
    name      = "grafana-dashboard-pod-logs"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "pod-logs-dashboard.json" = file("${path.module}/dashboards/pod-logs-dashboard.json")
  }
}

resource "helm_release" "prometheus" {
  count          = var.test_mode ? 0 : 1
  name           = "prometheus"
  repository     = "https://prometheus-community.github.io/helm-charts"
  chart          = "kube-prometheus-stack"
  namespace      = kubernetes_namespace_v1.monitoring.metadata[0].name
  version        = var.prometheus_chart_version
  timeout        = var.helm_timeout
  wait           = true
  take_ownership = true

  values = [
    yamlencode(merge(
      {
        alertmanager = {
          enabled = var.enable_alertmanager
        }
        prometheus = {
          serviceAccount = {
            create = true
            name   = "prometheus"
            annotations = {
              "eks.amazonaws.com/role-arn" = aws_iam_role.prometheus_s3.arn
            }
          }
          prometheusSpec = merge(
            {
              externalLabels = {
                cluster = "popcorn-${var.environment}"
              }
              thanos = {
                objectStorageConfig = {
                  existingSecret = {
                    name = kubernetes_secret_v1.thanos_objstore_config.metadata[0].name
                    key  = "object-store.yaml"
                  }
                }
              }
              storageSpec = {
                emptyDir = {
                  sizeLimit = var.prometheus_storage_size
                }
              }
              retention = var.prometheus_retention
              resources = {
                requests = {
                  cpu    = var.prometheus_cpu_request
                  memory = var.prometheus_memory_request
                }
                limits = {
                  cpu    = var.prometheus_cpu_limit
                  memory = var.prometheus_memory_limit
                }
              }
            },
            length(var.node_selector) > 0 ? { nodeSelector = var.node_selector } : {}
          )
        }

        grafana = merge(
          {
            enabled       = true
            adminPassword = var.grafana_password
            sidecar = {
              dashboards = {
                enabled = true
                label   = "grafana_dashboard"
              }
            }
            persistence = {
              enabled = false
            }
            resources = {
              requests = {
                cpu    = var.grafana_cpu_request
                memory = var.grafana_memory_request
              }
              limits = {
                cpu    = var.grafana_cpu_limit
                memory = var.grafana_memory_limit
              }
            }
            service = {
              type = var.grafana_service_type
            }
            "grafana.ini" = {
              server = {
                root_url = "%(protocol)s://%(domain)s:%(http_port)s/"
              }
            }
            admin = {
              existingSecret = kubernetes_secret_v1.grafana_credentials.metadata[0].name
            }
          },
          length(var.node_selector) > 0 ? { nodeSelector = var.node_selector } : {}
        )

        nodeExporter = {
          enabled = true
          resources = {
            requests = {
              cpu    = var.node_exporter_cpu_request
              memory = var.node_exporter_memory_request
            }
            limits = {
              cpu    = var.node_exporter_cpu_limit
              memory = var.node_exporter_memory_limit
            }
          }
        }

        kubeStateMetrics = {
          enabled = true
          resources = {
            requests = {
              cpu    = var.kube_state_metrics_cpu_request
              memory = var.kube_state_metrics_memory_request
            }
            limits = {
              cpu    = var.kube_state_metrics_cpu_limit
              memory = var.kube_state_metrics_memory_limit
            }
          }
        }
      },
      var.kube_prometheus_disable_admission_webhooks ? {
        prometheusOperator = {
          # Chart mounts admission TLS whenever tls.enabled (default true); webhooks-only=false leaves
          # operator stuck mounting secret …-admission if patch job never created it.
          tls = {
            enabled = false
          }
          admissionWebhooks = {
            enabled = false
            patch = {
              enabled = false
            }
          }
        }
      } : {}
    ))
  ]

  depends_on = [kubernetes_namespace_v1.monitoring]
}

resource "helm_release" "dcgm_exporter" {
  count          = !var.test_mode && var.enable_dcgm_exporter ? 1 : 0
  name           = "dcgm-exporter"
  repository     = "https://nvidia.github.io/dcgm-exporter/helm-charts"
  chart          = "dcgm-exporter"
  namespace      = kubernetes_namespace_v1.monitoring.metadata[0].name
  version        = var.dcgm_exporter_chart_version
  timeout        = var.helm_timeout
  wait           = true
  take_ownership = true

  values = [
    yamlencode({
      nodeSelector = var.dcgm_node_selector
      tolerations  = var.dcgm_tolerations
      serviceMonitor = {
        enabled     = true
        namespace   = kubernetes_namespace_v1.monitoring.metadata[0].name
        honorLabels = false
        additionalLabels = {
          release = var.prometheus_release_label
        }
      }
    })
  ]

  depends_on = [helm_release.prometheus]
}

resource "helm_release" "loki" {
  count          = var.test_mode ? 0 : 1
  name           = "loki"
  repository     = "https://grafana.github.io/helm-charts"
  chart          = "loki-stack"
  namespace      = kubernetes_namespace_v1.monitoring.metadata[0].name
  version        = var.loki_chart_version
  timeout        = var.helm_timeout
  wait           = true
  take_ownership = true

  values = [
    yamlencode({
      grafana = {
        enabled = false
      }
      loki = merge(
        {
          enabled   = true
          isDefault = false
          persistence = {
            enabled = false
          }
          serviceAccount = {
            create = true
            name   = "loki"
            annotations = {
              "eks.amazonaws.com/role-arn" = aws_iam_role.loki_s3.arn
            }
          }
          resources = {
            requests = {
              cpu    = var.loki_cpu_request
              memory = var.loki_memory_request
            }
            limits = {
              cpu    = var.loki_cpu_limit
              memory = var.loki_memory_limit
            }
          }
          config = {
            schema_config = {
              configs = [{
                from         = "2020-10-24"
                store        = "boltdb-shipper"
                object_store = "s3"
                schema       = "v11"
                index = {
                  prefix = "index_"
                  period = "24h"
                }
              }]
            }
            storage_config = {
              aws = {
                s3 = "s3://${var.aws_region}/${aws_s3_bucket.loki_logs.bucket}"
              }
              boltdb_shipper = {
                active_index_directory = "/data/boltdb-shipper-active"
                cache_location         = "/data/boltdb-shipper-cache"
                cache_ttl              = "24h"
                shared_store           = "s3"
              }
            }
            compactor = {
              working_directory             = "/data/compactor"
              shared_store                  = "s3"
              compaction_interval           = "10m"
              retention_enabled             = true
              retention_delete_delay        = "2h"
              retention_delete_worker_count = 150
            }
            limits_config = {
              retention_period              = var.loki_retention
              enforce_metric_name           = false
              reject_old_samples            = true
              reject_old_samples_max_age    = "168h"
              max_cache_freshness_per_query = "10m"
              split_queries_by_interval     = "15m"
              max_query_parallelism         = 32
              max_streams_per_user          = 1000
              max_line_size                 = 256000
            }
          }
        },
        length(var.node_selector) > 0 ? { nodeSelector = var.node_selector } : {}
      )

      promtail = {
        enabled = true
        resources = {
          requests = {
            cpu    = var.promtail_cpu_request
            memory = var.promtail_memory_request
          }
          limits = {
            cpu    = var.promtail_cpu_limit
            memory = var.promtail_memory_limit
          }
        }
        tolerations = var.promtail_tolerations
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.monitoring]
}

resource "kubernetes_config_map_v1" "gpu_dashboard" {
  count = !var.test_mode && var.enable_gpu_dashboard ? 1 : 0

  metadata {
    name      = "grafana-dashboard-popcorn-gpu"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "popcorn-gpu-dashboard.json" = templatefile("${path.module}/dashboards/popcorn-gpu-dashboard.json.tftpl", {
      gpu_dashboard_default_namespace = var.gpu_dashboard_default_namespace
    })
  }

  depends_on = [helm_release.prometheus]
}
