# EKS Outputs

output "cluster_name" {
  description = "Cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks.cluster_version
}

output "kubectl_config_command" {
  description = "Run this to set up kubectl"
  value       = module.eks.kubectl_config_command
}

output "node_group_status" {
  description = "Node group health"
  value       = module.eks.node_group_status
}

output "oidc_provider_arn" {
  description = "For IRSA (IAM roles for pods)"
  value       = module.eks.oidc_provider_arn
}
