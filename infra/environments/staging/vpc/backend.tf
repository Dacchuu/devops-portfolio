terraform {
  backend "s3" {
    bucket         = "popcorn-terraform-state-bucket"
    key            = "environments/staging/vpc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}