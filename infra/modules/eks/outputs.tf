# EKS Module Outputs

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = aws_security_group.cluster.id
}

output "cluster_certificate_authority_data" {
  description = "Certificate for kubectl authentication"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN (for IRSA - IAM roles for pods)"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "node_group_status" {
  description = "Node group status"
  value       = var.create_main_node_group ? aws_eks_node_group.main[0].status : "not-created (managed outside Terraform)"
}

output "node_role_arn" {
  description = "IAM role ARN for nodes"
  value       = aws_iam_role.node_group.arn
}

output "kubectl_config_command" {
  description = "Run this to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.main.name}"
}

output "cluster_admin_users" {
  description = "IAM principal ARNs intended for cluster admin (configure EKS access entries or aws-auth as needed)"
  value       = var.admin_users
}

output "cluster_developer_users" {
  description = "IAM principal ARNs intended for read-only cluster access"
  value       = var.developer_users
}

output "deployment_region" {
  description = "Region passed into the module (caller workload region)"
  value       = var.region
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for the Cluster Autoscaler service account"
  value       = aws_iam_role.cluster_autoscaler.arn
}
