terraform {
  backend "s3" {
    bucket         = "eicon-terraform-state-bucket"
    key            = "environments/production/monitoring/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
