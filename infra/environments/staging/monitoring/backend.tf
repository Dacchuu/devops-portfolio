# Terraform does not allow variables inside the backend block.
# Override bucket/key/region per workspace via: terraform init -backend-config=...
terraform {
  backend "s3" {
    bucket         = "popcorn-terraform-state-bucket"
    key            = "environments/staging/monitoring/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
