#!/bin/bash

# Azure Storage Cost Optimization Demo Setup Script
# Creates 20 storage accounts with different configurations for cost optimization demonstrations
# 
# Repository: https://github.com/demirsenturk/azure-storage-demo
# Purpose: Educational demonstration of Azure Storage cost optimization strategies
# Features: Mixed V1/V2 accounts, all redundancy types, lifecycle management examples
# Cost Warning: This will create billable resources - clean up after testing!

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-storage-demo"
LOCATION="Sweden Central"
BASE_NAME="stgdemo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================="
echo "Azure Storage Cost Optimization Demo Setup"
echo "=================================================="
echo -e "This script will create 20 storage accounts with different configurations"
echo -e "for cost optimization and lifecycle management demonstrations."
echo ""
echo -e "${YELLOW}⚠️  COST WARNING: This will create billable Azure resources!"
echo -e "Estimated daily cost: \$5-20 depending on region and usage"
echo -e "Remember to run cleanup-storage-demo.sh after testing!${NC}"
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

# Confirm with user
read -p "Do you want to proceed with creating 20 storage accounts? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

# Check if storage accounts with our naming pattern already exist
EXISTING_ACCOUNTS=$(az storage account list --resource-group "$RESOURCE_GROUP_NAME" --query "[?starts_with(name, '$BASE_NAME')].name" -o tsv 2>/dev/null | wc -l)

if [ "$EXISTING_ACCOUNTS" -gt 0 ]; then
    print_warning "Found $EXISTING_ACCOUNTS existing storage accounts with prefix '$BASE_NAME' in resource group '$RESOURCE_GROUP_NAME'"
    echo "This might cause conflicts or update existing accounts."
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled. Consider running cleanup script first or using a different BASE_NAME."
        exit 0
    fi
fi

# Create resource group if it doesn't exist
print_status "Creating resource group: $RESOURCE_GROUP_NAME"
az group create --name $RESOURCE_GROUP_NAME --location "$LOCATION" --output none

# Function to create storage account with specific configuration
create_storage_account() {
    local NAME=$1
    local SKU=$2
    local KIND=$3
    local ACCESS_TIER=$4
    local VERSIONING=$5
    local BLOB_SOFT_DELETE=$6
    local CONTAINER_SOFT_DELETE=$7
    local DESCRIPTION=$8
    
    print_status "Creating storage account: $NAME ($DESCRIPTION)"
    
    # Create the storage account with conditional access tier parameter
    if [ "$KIND" = "Storage" ]; then
        # Legacy V1 accounts don't support access tiers
        az storage account create \
            --name "$NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --location "$LOCATION" \
            --sku "$SKU" \
            --kind "$KIND" \
            --allow-blob-public-access false \
            --min-tls-version TLS1_2 \
            --output none
    else
        # StorageV2, BlobStorage, and BlockBlobStorage support access tiers
        az storage account create \
            --name "$NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --location "$LOCATION" \
            --sku "$SKU" \
            --kind "$KIND" \
            --access-tier "$ACCESS_TIER" \
            --allow-blob-public-access false \
            --min-tls-version TLS1_2 \
            --output none
    fi
    
    # Wait for storage account to be fully provisioned
    print_status "Waiting for storage account $NAME to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if az storage account show --name "$NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "provisioningState" -o tsv 2>/dev/null | grep -q "Succeeded"; then
            break
        fi
        echo "  Attempt $attempt/$max_attempts - waiting for $NAME to be ready..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Storage account $NAME failed to provision within expected time"
        return 1
    fi
    
    # Skip advanced features for legacy V1 accounts
    if [ "$KIND" = "Storage" ]; then
        print_status "Skipping advanced features for legacy V1 account: $NAME"
        # Add tags for organization
        az storage account update \
            --name "$NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --tags \
                Purpose="LifecycleDemo" \
                Configuration="$DESCRIPTION" \
                CreatedBy="StorageDemoScript" \
                AccountType="LegacyV1" \
            --output none
        
        echo -e "  ${GREEN}✓${NC} $NAME created successfully (Legacy V1 - limited features)"
        return 0
    fi
    
    # Configure blob versioning if specified (only for StorageV2 and newer)
    if [ "$VERSIONING" = "true" ]; then
        print_status "Enabling versioning for $NAME..."
        local retries=3
        local retry=1
        while [ $retry -le $retries ]; do
            if az storage account blob-service-properties update \
                --account-name "$NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --enable-versioning true \
                --output none 2>/dev/null; then
                break
            fi
            echo "  Retry $retry/$retries for versioning configuration..."
            sleep 5
            retry=$((retry + 1))
        done
    fi
    
    # Configure blob soft delete
    if [ "$BLOB_SOFT_DELETE" -gt 0 ]; then
        print_status "Configuring blob soft delete for $NAME ($BLOB_SOFT_DELETE days)..."
        local retries=3
        local retry=1
        while [ $retry -le $retries ]; do
            if az storage account blob-service-properties update \
                --account-name "$NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --enable-delete-retention true \
                --delete-retention-days "$BLOB_SOFT_DELETE" \
                --output none 2>/dev/null; then
                break
            fi
            echo "  Retry $retry/$retries for blob soft delete configuration..."
            sleep 5
            retry=$((retry + 1))
        done
    fi
    
    # Configure container soft delete
    if [ "$CONTAINER_SOFT_DELETE" -gt 0 ]; then
        print_status "Configuring container soft delete for $NAME ($CONTAINER_SOFT_DELETE days)..."
        local retries=3
        local retry=1
        while [ $retry -le $retries ]; do
            if az storage account blob-service-properties update \
                --account-name "$NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --enable-container-delete-retention true \
                --container-delete-retention-days "$CONTAINER_SOFT_DELETE" \
                --output none 2>/dev/null; then
                break
            fi
            echo "  Retry $retry/$retries for container soft delete configuration..."
            sleep 5
            retry=$((retry + 1))
        done
    fi
    
    # Add tags for organization
    az storage account update \
        --name "$NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --tags \
            Purpose="LifecycleDemo" \
            Configuration="$DESCRIPTION" \
            CreatedBy="StorageDemoScript" \
        --output none
    
    echo -e "  ${GREEN}✓${NC} $NAME created successfully"
}

echo ""
print_status "Starting storage account creation..."

# Create 20 storage accounts with different configurations
# Each account has a unique combination of settings for demonstration

# 1-5: Standard LRS accounts with different access tiers and features
create_storage_account "${BASE_NAME}01std" "Standard_LRS" "StorageV2" "Hot" "false" "0" "0" "Standard_LRS_Hot_NoVersioning"
create_storage_account "${BASE_NAME}02std" "Standard_LRS" "StorageV2" "Cool" "true" "7" "7" "Standard_LRS_Cool_WithVersioning"
create_storage_account "${BASE_NAME}03std" "Standard_LRS" "StorageV2" "Hot" "true" "14" "0" "Standard_LRS_Hot_BlobSoftDelete"
create_storage_account "${BASE_NAME}04std" "Standard_LRS" "BlobStorage" "Cool" "false" "30" "14" "BlobStorage_Cool_SoftDelete"
create_storage_account "${BASE_NAME}05std" "Standard_LRS" "StorageV2" "Cool" "true" "90" "30" "Standard_LRS_Cool_ArchiveReady"

# 6-10: Standard GRS accounts for geo-redundancy scenarios
create_storage_account "${BASE_NAME}06grs" "Standard_GRS" "StorageV2" "Hot" "false" "0" "0" "Standard_GRS_Hot_Basic"
create_storage_account "${BASE_NAME}07grs" "Standard_GRS" "StorageV2" "Cool" "true" "7" "7" "Standard_GRS_Cool_WithVersioning"
create_storage_account "${BASE_NAME}08grs" "Standard_RAGRS" "StorageV2" "Hot" "true" "14" "14" "ReadAccess_GRS_Hot_SoftDelete"
create_storage_account "${BASE_NAME}09grs" "Standard_GRS" "StorageV2" "Cool" "false" "365" "90" "Standard_GRS_Cool_YearRetention"
create_storage_account "${BASE_NAME}10grs" "Standard_RAGRS" "StorageV2" "Cool" "true" "30" "30" "ReadAccess_GRS_Cool_MonthRetention"

# 11-15: Zone Redundant Storage accounts
create_storage_account "${BASE_NAME}11zrs" "Standard_ZRS" "StorageV2" "Hot" "false" "0" "0" "Standard_ZRS_Hot_Basic"
create_storage_account "${BASE_NAME}12zrs" "Standard_ZRS" "StorageV2" "Cool" "true" "7" "0" "Standard_ZRS_Cool_Versioning"
create_storage_account "${BASE_NAME}13zrs" "Standard_GZRS" "StorageV2" "Hot" "true" "14" "14" "GeoZone_Redundant_Hot"
create_storage_account "${BASE_NAME}14zrs" "Standard_RAGZRS" "StorageV2" "Cool" "true" "30" "30" "ReadAccess_GeoZone_Cool"
create_storage_account "${BASE_NAME}15zrs" "Standard_ZRS" "StorageV2" "Cool" "false" "180" "60" "Standard_ZRS_Cool_LongRetention"

# 16-20: Premium and Legacy V1 accounts for Azure Advisor demonstration
create_storage_account "${BASE_NAME}16prm" "Premium_LRS" "StorageV2" "Hot" "false" "0" "0" "Premium_LRS_Hot_Basic"
create_storage_account "${BASE_NAME}17v1" "Standard_LRS" "Storage" "Hot" "false" "0" "0" "Legacy_V1_LRS_Account"
create_storage_account "${BASE_NAME}18v1" "Standard_GRS" "Storage" "Hot" "false" "0" "0" "Legacy_V1_GRS_Account"
create_storage_account "${BASE_NAME}19v1" "Standard_RAGRS" "Storage" "Hot" "false" "0" "0" "Legacy_V1_RAGRS_Account"
create_storage_account "${BASE_NAME}20v1" "Standard_ZRS" "Storage" "Hot" "false" "0" "0" "Legacy_V1_ZRS_Account"

echo ""
print_status "All storage accounts created successfully!"

# Create sample containers and blobs for lifecycle management demonstration
print_status "Creating sample containers and uploading demo files..."

# Function to create containers and sample data
create_demo_data() {
    local ACCOUNT_NAME=$1
    local CONTAINER_NAME=$2
    
    # Get storage account key
    ACCOUNT_KEY=$(az storage account keys list --account-name "$ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "[0].value" -o tsv)
    
    # Create container
    az storage container create \
        --name "$CONTAINER_NAME" \
        --account-name "$ACCOUNT_NAME" \
        --account-key "$ACCOUNT_KEY" \
        --output none
    
    # Create some sample files with different sizes and dates
    echo "Sample data for lifecycle management demo - Created on $(date)" > /tmp/sample-file.txt
    echo "This is a larger sample file for testing lifecycle policies. $(date)" > /tmp/large-sample.txt
    for i in {1..100}; do
        echo "Line $i - Additional content for testing purposes" >> /tmp/large-sample.txt
    done
    
    # Upload sample files
    az storage blob upload \
        --file /tmp/sample-file.txt \
        --container-name "$CONTAINER_NAME" \
        --name "demo-files/small-file-$(date +%Y%m%d).txt" \
        --account-name "$ACCOUNT_NAME" \
        --account-key "$ACCOUNT_KEY" \
        --output none
    
    az storage blob upload \
        --file /tmp/large-sample.txt \
        --container-name "$CONTAINER_NAME" \
        --name "demo-files/large-file-$(date +%Y%m%d).txt" \
        --account-name "$ACCOUNT_NAME" \
        --account-key "$ACCOUNT_KEY" \
        --output none
}

# Create demo data in a few selected accounts
create_demo_data "${BASE_NAME}01std" "demo-container"
create_demo_data "${BASE_NAME}07grs" "lifecycle-demo"
create_demo_data "${BASE_NAME}13zrs" "cost-optimization"

# Clean up temporary files
rm -f /tmp/sample-file.txt /tmp/large-sample.txt

echo ""
echo -e "${GREEN}=================================================="
echo "✓ Demo Setup Complete!"
echo "=================================================="
echo -e "Created 20 storage accounts in resource group: $RESOURCE_GROUP_NAME"
echo ""
echo "Storage Account Summary:"
echo "• 5 Standard LRS accounts with various configurations"
echo "• 5 Geo-redundant accounts (GRS/RA-GRS)"
echo "• 5 Zone-redundant accounts (ZRS/GZRS/RA-GZRS)"
echo "• 1 Premium account for performance comparison"
echo "• 4 Legacy V1 accounts showcasing older storage technology"
echo ""
echo "Features demonstrated:"
echo "• Different storage tiers (Hot, Cool, Archive)"
echo "• Blob versioning enabled/disabled"
echo "• Soft delete with various retention periods"
echo "• Different redundancy options"
echo "• Legacy V1 vs modern V2 account types (4 V1 accounts)"
echo ""
echo "Cost Optimization Opportunities:"
echo "• 4 Legacy V1 accounts demonstrate upgrade potential"
echo "• Feature limitations of V1 accounts vs V2 capabilities"
echo "• Cost benefits of modern storage account types"
echo ""
echo "Next steps for your demo:"
echo "1. Configure lifecycle management policies"
echo "2. Monitor cost analytics"
echo "3. Test tier transitions"
echo "4. Demonstrate access patterns"
echo ""
echo -e "Resource Group: ${BLUE}$RESOURCE_GROUP_NAME${NC}"
echo -e "Location: ${BLUE}$LOCATION${NC}"
echo ""
echo -e "${YELLOW}💡 Don't forget to run ./cleanup-storage-demo.sh when done!"
echo -e "📚 See README.md for detailed usage instructions and examples${NC}"
