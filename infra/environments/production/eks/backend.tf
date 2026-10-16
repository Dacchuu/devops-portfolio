# Backend configuration for production EKS

terraform {
  backend "s3" {
    bucket         = "eicon-terraform-state-bucket"
    key            = "environments/production/eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
