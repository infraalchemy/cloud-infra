#!/bin/bash
set -e

echo "Starting Terraform deployment..."

# Initialize Terraform
terraform init

# Show execution plan
terraform plan

# Apply infrastructure changes
terraform apply -auto-approve

echo "Terraform deployment complete."
