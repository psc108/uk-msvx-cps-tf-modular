#!/bin/bash
# Destroy CSO infrastructure

WORKSPACE=$(terraform workspace show)
echo "Destroying infrastructure for workspace: $WORKSPACE"

echo "Running: terraform destroy -auto-approve $@"
terraform destroy -auto-approve "$@"