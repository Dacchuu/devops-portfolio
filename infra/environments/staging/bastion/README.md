# Staging Bastion

Deploy **after** the staging VPC. Uses VPC remote state and holds all bastion and DevOps SSH configuration in one place (no duplication across environments).

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```
