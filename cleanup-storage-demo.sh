#!/bin/bash

# Azure Storage Demo Cleanup Script
# Removes all resources created by the storage demo setup script
#
# Repository: https://github.com/demirsenturk/azure-storage-demo
# Purpose: Clean up educational demo resources to avoid ongoing costs

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-storage-demo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================="
echo "Azure Storage Demo Cleanup"
echo "=================================================="
echo -e "This script will delete the storage demo resource group"
echo -e "and all associated storage accounts.${NC}"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Azure CLI is installed and user is logged in
if ! az account show &> /dev/null; then
    print_error "Please log in to Azure CLI first using 'az login'"
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)

echo -e "${BLUE}Current Subscription:${NC}"
echo "  Name: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo ""

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Resource group '$RESOURCE_GROUP_NAME' does not exist."
    echo "Nothing to clean up."
    exit 0
fi

# Show what will be deleted
print_status "Found resource group: $RESOURCE_GROUP_NAME"
print_status "Listing storage accounts to be deleted..."

STORAGE_ACCOUNTS=$(az storage account list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" -o tsv)

if [ -z "$STORAGE_ACCOUNTS" ]; then
    echo "No storage accounts found in resource group."
else
    echo ""
    echo "Storage accounts that will be deleted:"
    for SA in $STORAGE_ACCOUNTS; do
        echo "  - $SA"
    done
fi

echo ""
print_warning "⚠️  WARNING: This action cannot be undone!"
print_warning "All storage accounts and their data will be permanently deleted."
echo ""

# Double confirmation
read -p "Are you sure you want to delete the resource group '$RESOURCE_GROUP_NAME' and all its contents? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

read -p "Type 'DELETE' to confirm: " CONFIRM
if [ "$CONFIRM" != "DELETE" ]; then
    echo "Confirmation text does not match. Operation cancelled."
    exit 0
fi

print_status "Deleting resource group: $RESOURCE_GROUP_NAME"
print_status "This may take several minutes..."

az group delete --name "$RESOURCE_GROUP_NAME" --yes --no-wait

echo ""
echo -e "${GREEN}=================================================="
echo "✓ Cleanup Initiated!"
echo "=================================================="
echo -e "Resource group '$RESOURCE_GROUP_NAME' has been scheduled for deletion."
echo "The deletion process will continue in the background."
echo ""
echo "You can check the deletion status with:"
echo -e "${BLUE}az group show --name $RESOURCE_GROUP_NAME${NC}"
echo -e "(This command will return an error once deletion is complete)${NC}"
