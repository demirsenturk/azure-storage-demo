#!/bin/bash

# =======================================================
# Azure Storage Lifecycle Management Demo Script
# =======================================================
# This script demonstrates lifecycle policy implementation
# using the actual storage accounts created by the demo

echo "=================================================="
echo "Azure Storage Lifecycle Management Demo"
echo "=================================================="

# Set variables with your actual storage account names
RESOURCE_GROUP="rg-storage-demo"

# Key accounts for lifecycle demos (with all features)
LIFECYCLE_ACCOUNT="stgdemo73842515805std"    # Cool tier with all features
GRS_LIFECYCLE="stgdemo73842515807grs"        # GRS Cool with versioning
VERSION_ACCOUNT="stgdemo73842515802std"      # LRS Cool with versioning
ZRS_ACCOUNT="stgdemo73842515812zrs"          # ZRS Cool with versioning

echo "Selected accounts for lifecycle demonstration:"
echo "• Main Demo Account: $LIFECYCLE_ACCOUNT (Cool, All Features)"
echo "• GRS Demo Account: $GRS_LIFECYCLE (GRS, Cool, Versioning)"
echo "• Version Demo Account: $VERSION_ACCOUNT (LRS, Cool, Versioning)"
echo "• ZRS Demo Account: $ZRS_ACCOUNT (ZRS, Cool, Versioning)"
echo ""

# Function to check if account exists and is ready
check_account() {
    local account=$1
    echo "Checking account: $account"
    if az storage account show --name $account --resource-group $RESOURCE_GROUP &>/dev/null; then
        echo "✓ Account $account is ready"
        return 0
    else
        echo "✗ Account $account not found"
        return 1
    fi
}

# Function to apply lifecycle policy
apply_policy() {
    local account=$1
    local policy_file=$2
    local description=$3
    
    echo ""
    echo "Applying $description to $account..."
    
    if az storage account management-policy create \
        --account-name $account \
        --resource-group $RESOURCE_GROUP \
        --policy @$policy_file; then
        echo "✓ Successfully applied $description to $account"
    else
        echo "✗ Failed to apply $description to $account"
    fi
}

# Function to create test container and data
create_test_data() {
    local account=$1
    echo ""
    echo "Creating test data in $account..."
    
    # Create lifecycle-demo container
    az storage container create \
        --account-name $account \
        --name lifecycle-demo \
        --auth-mode login &>/dev/null
    
    # Create test files for different scenarios
    echo "Recent application data - $(date)" > recent-data.txt
    echo "Log data from last month" > monthly-log.txt
    echo "Backup archive data" > backup-archive.tar
    echo "Compliance audit document" > audit-report.pdf
    echo "Business quarterly report" > quarterly-report.xlsx
    
    # Upload to different prefixes
    az storage blob upload --account-name $account --container-name lifecycle-demo --file recent-data.txt --name data/recent-data.txt --auth-mode login &>/dev/null
    az storage blob upload --account-name $account --container-name lifecycle-demo --file monthly-log.txt --name logs/monthly-log-$(date +%Y%m).txt --auth-mode login &>/dev/null
    az storage blob upload --account-name $account --container-name lifecycle-demo --file backup-archive.tar --name backups/backup-$(date +%Y%m).tar --auth-mode login &>/dev/null
    az storage blob upload --account-name $account --container-name lifecycle-demo --file audit-report.pdf --name compliance/audit-$(date +%Y).pdf --auth-mode login &>/dev/null
    az storage blob upload --account-name $account --container-name lifecycle-demo --file quarterly-report.xlsx --name business/report-$(date +%Y%m).xlsx --auth-mode login &>/dev/null
    
    # Clean up local files
    rm -f recent-data.txt monthly-log.txt backup-archive.tar audit-report.pdf quarterly-report.xlsx
    
    echo "✓ Test data created with different prefixes (data/, logs/, backups/, compliance/, business/)"
}

# Function to show current blob tiers
show_blob_tiers() {
    local account=$1
    echo ""
    echo "Current blob tiers in $account:"
    az storage blob list \
        --account-name $account \
        --container-name lifecycle-demo \
        --query "[].{Name:name, Tier:properties.blobTier, Size:properties.contentLength, LastModified:properties.lastModified}" \
        --output table \
        --auth-mode login 2>/dev/null || echo "No blobs found or container doesn't exist"
}

# Function to show current policies
show_policies() {
    local account=$1
    echo ""
    echo "Current lifecycle policies for $account:"
    az storage account management-policy show \
        --account-name $account \
        --resource-group $RESOURCE_GROUP \
        --query "policy.rules[].{Name:name, Enabled:enabled, Filters:definition.filters, Actions:definition.actions}" \
        --output table 2>/dev/null || echo "No lifecycle policies configured"
}

# Main demonstration
echo "Starting lifecycle management demonstration..."
echo ""

# Check all accounts
echo "1. Verifying storage accounts..."
for account in $LIFECYCLE_ACCOUNT $GRS_LIFECYCLE $VERSION_ACCOUNT $ZRS_ACCOUNT; do
    check_account $account
done

# Create test data in main account
echo ""
echo "2. Creating test data..."
create_test_data $LIFECYCLE_ACCOUNT

# Show initial state
show_blob_tiers $LIFECYCLE_ACCOUNT

# Apply different policies to different accounts
echo ""
echo "3. Applying lifecycle policies..."

# Basic policy to main account
apply_policy $LIFECYCLE_ACCOUNT "basic-lifecycle.json" "Basic Cost Optimization Policy"

# Aggressive policy to GRS account
apply_policy $GRS_LIFECYCLE "aggressive-lifecycle.json" "Aggressive Cost Optimization Policy"

# Version management to versioning-enabled account
apply_policy $VERSION_ACCOUNT "version-lifecycle.json" "Version Management Policy"

# Show applied policies
echo ""
echo "4. Reviewing applied policies..."
show_policies $LIFECYCLE_ACCOUNT
show_policies $GRS_LIFECYCLE

# Cost comparison information
echo ""
echo "=================================================="
echo "Cost Optimization Scenarios Demonstrated:"
echo "=================================================="
echo "Account Types Created:"
echo "• Basic LRS (minimal features): stgdemo73842515801std"
echo "• Cool with lifecycle: $LIFECYCLE_ACCOUNT"
echo "• GRS with aggressive lifecycle: $GRS_LIFECYCLE"
echo "• ZRS with version management: $ZRS_ACCOUNT"
echo ""
echo "Lifecycle Policy Cost Impact:"
echo "• Hot to Cool transition (30 days): ~50% storage cost reduction"
echo "• Cool to Archive transition (90 days): ~75% storage cost reduction"
echo "• Version cleanup (365 days): Eliminates old version storage costs"
echo "• Prefix-based policies: Targeted optimization for specific data types"
echo ""
echo "Next Steps:"
echo "1. Monitor policy execution over time"
echo "2. Upload more test data to see tier transitions"
echo "3. Compare costs between accounts with/without policies"
echo "4. Test archive tier retrieval scenarios"
echo ""
echo "💡 Lifecycle policies execute once per day by Azure"
echo "📊 Check Azure Portal Cost Management for detailed cost analysis"
echo "🧹 Remember to run ./cleanup-storage-demo.sh when done!"
echo "=================================================="
