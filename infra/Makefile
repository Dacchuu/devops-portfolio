# Terraform Infrastructure Makefile
# Provides shortcuts for common Terraform development tasks

.PHONY: fmt validate test lint check

# Format Terraform code
fmt:
	@echo "Running terraform fmt..."
	terraform fmt -recursive

# Validate Terraform configuration
validate:
	@echo "Running terraform validate..."
	terraform validate

# Run Terraform tests
test:
	@echo "Running terraform tests..."
	terraform test

# Run TFLint
lint:
	@echo "Running TFLint..."
	tflint --recursive

# Run all checks (recommended before committing)
check: fmt validate test lint
	@echo "All Terraform checks completed successfully."

# Initialize Terraform (helper)
init:
	@echo "Initializing Terraform..."
	terraform init

# Show Terraform plan (example for production VPC)
plan-vpc:
	cd environments/production/vpc && terraform init && terraform plan

# Apply Terraform plan (example for production VPC)
apply-vpc:
	cd environments/production/vpc && terraform apply