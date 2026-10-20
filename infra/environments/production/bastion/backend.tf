terraform {
  backend "s3" {
    bucket         = "popcorn-terraform-state-bucket"
    key            = "environments/production/bastion/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
