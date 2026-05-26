#!/bin/bash
# Run this ONCE before the first terraform init to create the remote state backend.
# After this, GitHub Actions will use it automatically.
#
# Usage: bash bootstrap/setup_backend.sh

set -e

RESOURCE_GROUP="rg-grouper-tf-state"
STORAGE_ACCOUNT="stgroupertfstate"   # must be globally unique — change if taken
CONTAINER="tfstate"
LOCATION="eastus"

echo "Creating resource group: $RESOURCE_GROUP"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "Creating storage account: $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false

echo "Creating blob container: $CONTAINER"
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login

echo ""
echo "Done. Update backend.tf with these values if you changed them:"
echo "  storage_account_name = \"$STORAGE_ACCOUNT\""
echo "  resource_group_name  = \"$RESOURCE_GROUP\""
echo "  container_name       = \"$CONTAINER\""
