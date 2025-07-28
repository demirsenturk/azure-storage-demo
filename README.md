# Azure Storage Cost Optimization Demo

Automated scripts to create 20 Azure Storage accounts with different configurations for demonstrating cost optimization strategies and lifecycle management policies.

## What This Creates

- **20 Storage Accounts** with different configurations
- **4 Legacy V1 + 16 Modern V2** accounts for comparison
- **All redundancy types** (LRS, GRS, RA-GRS, ZRS, GZRS, RA-GZRS)
- **Multiple access tiers** (Hot, Cool, Archive via lifecycle policies)
- **Various features** (versioning, soft delete, retention periods)
- **Sample data** for immediate testing

## Quick Start

```bash
# Clone the repository
git clone https://github.com/demirsenturk/azure-storage-demo.git
cd azure-storage-demo

# Make executable and run
chmod +x create-storage-demo.sh
./create-storage-demo.sh

# Clean up when done
chmod +x cleanup-storage-demo.sh
./cleanup-storage-demo.sh
```

## Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI access (Azure Cloud Shell recommended)

## Storage Accounts Created

> **Note:** Storage account names are automatically randomized with a unique suffix (e.g., `stgdemo12345601std`) to avoid naming conflicts when running the script multiple times. The examples below show the pattern without the random suffix.

### Standard LRS Accounts (1-5)
| Account | Type | Tier | Features |
|---------|------|------|----------|
| stgdemo01std | StorageV2 | Hot | Basic |
| stgdemo02std | StorageV2 | Cool | Versioning + Soft Delete |
| stgdemo03std | StorageV2 | Hot | Versioning + Blob Soft Delete |
| stgdemo04std | BlobStorage | Cool | Soft Delete |
| stgdemo05std | StorageV2 | Cool | All Features |

### Geo-Redundant Accounts (6-10)
| Account | Type | Tier | Redundancy | Features |
|---------|------|------|------------|----------|
| stgdemo06grs | StorageV2 | Hot | GRS | Basic |
| stgdemo07grs | StorageV2 | Cool | GRS | Versioning + Soft Delete |
| stgdemo08grs | StorageV2 | Hot | RA-GRS | Versioning + Soft Delete |
| stgdemo09grs | StorageV2 | Cool | GRS | Long Retention |
| stgdemo10grs | StorageV2 | Cool | RA-GRS | All Features |

### Zone-Redundant Accounts (11-15)
| Account | Type | Tier | Redundancy | Features |
|---------|------|------|------------|----------|
| stgdemo11zrs | StorageV2 | Hot | ZRS | Basic |
| stgdemo12zrs | StorageV2 | Cool | ZRS | Versioning |
| stgdemo13zrs | StorageV2 | Hot | GZRS | All Features |
| stgdemo14zrs | StorageV2 | Cool | RA-GZRS | All Features |
| stgdemo15zrs | StorageV2 | Cool | ZRS | Long Retention |

### Premium & Legacy Accounts (16-20)
| Account | Type | Tier | Purpose |
|---------|------|------|---------|
| stgdemo16prm | StorageV2 | Hot | Premium Performance |
| stgdemo17v1 | Storage (V1) | N/A | Legacy LRS |
| stgdemo18v1 | Storage (V1) | N/A | Legacy GRS |
| stgdemo19v1 | Storage (V1) | N/A | Legacy RA-GRS |
| stgdemo20v1 | Storage (V1) | N/A | Legacy ZRS |

## Demo Scenarios

### 1. Access Tier Comparison
- **Hot**: stgdemo01std, stgdemo06grs, stgdemo11zrs
- **Cool**: stgdemo02std, stgdemo07grs, stgdemo12zrs
- **Archive**: Use lifecycle policies on any Cool account

### 2. Redundancy Cost Analysis
- **LRS**: stgdemo01std (lowest cost)
- **ZRS**: stgdemo11zrs (regional protection)
- **GRS**: stgdemo06grs (geo-protection)
- **GZRS**: stgdemo13zrs (highest protection)

### 3. V1 vs V2 Comparison
- **V1 Accounts**: stgdemo17v1, stgdemo18v1, stgdemo19v1, stgdemo20v1
- **V2 Equivalent**: stgdemo01std, stgdemo06grs, stgdemo08grs, stgdemo11zrs

## Lifecycle Policy Example

```json
{
  "rules": [
    {
      "name": "CostOptimization",
      "enabled": true,
      "type": "Lifecycle",
      "definition": {
        "filters": {
          "blobTypes": ["blockBlob"]
        },
        "actions": {
          "baseBlob": {
            "tierToCool": {
              "daysAfterModificationGreaterThan": 30
            },
            "tierToArchive": {
              "daysAfterModificationGreaterThan": 90
            },
            "delete": {
              "daysAfterModificationGreaterThan": 365
            }
          }
        }
      }
    }
  ]
}
```

Apply the policy with:
```bash
# Option 1: Create the policy file first
cat > lifecycle-policy.json << 'EOF'
{
  "rules": [
    {
      "name": "CostOptimization",
      "enabled": true,
      "type": "Lifecycle",
      "definition": {
        "filters": {
          "blobTypes": ["blockBlob"]
        },
        "actions": {
          "baseBlob": {
            "tierToCool": {
              "daysAfterModificationGreaterThan": 30
            },
            "tierToArchive": {
              "daysAfterModificationGreaterThan": 90
            },
            "delete": {
              "daysAfterModificationGreaterThan": 365
            }
          }
        }
      }
    }
  ]
}
EOF

# Then apply the policy (replace with your actual storage account name)
az storage account management-policy create \
  --account-name stgdemoXXXXXXXXXXXstd \
  --resource-group rg-storage-demo \
  --policy @lifecycle-policy.json

# Option 2: Apply policy directly with inline JSON
az storage account management-policy create \
  --account-name stgdemoXXXXXXXXXXXstd \
  --resource-group rg-storage-demo \
  --policy '{
    "rules": [
      {
        "name": "CostOptimization",
        "enabled": true,
        "type": "Lifecycle",
        "definition": {
          "filters": {
            "blobTypes": ["blockBlob"]
          },
          "actions": {
            "baseBlob": {
              "tierToCool": {
                "daysAfterModificationGreaterThan": 30
              },
              "tierToArchive": {
                "daysAfterModificationGreaterThan": 90
              },
              "delete": {
                "daysAfterModificationGreaterThan": 365
              }
            }
          }
        }
      }
    ]
  }'
```

## Cost Monitoring & Testing

### Get Your Actual Storage Account Names
Since storage account names are randomized, use this command to list all accounts:
```bash
# List all storage accounts in the demo resource group
az storage account list \
  --resource-group rg-storage-demo \
  --query "[].name" \
  --output table
```

### Monitor Storage Costs
```bash
# Check storage usage by region
az storage account show-usage --location "Sweden Central"

# Get basic account information
az storage account show \
  --name <your-storage-account-name> \
  --resource-group rg-storage-demo
```

### Create Test Data
```bash
# Create a test file
echo "Small file content for testing" > small-file.txt

# Create container and upload file
az storage container create \
  --account-name <your-storage-account-name> \
  --name demo-container \
  --auth-mode login

az storage blob upload \
  --account-name <your-storage-account-name> \
  --container-name demo-container \
  --file small-file.txt \
  --name test-data/small-file.txt \
  --auth-mode login
```

### Archive Tier Demonstration
```bash
# Set a blob to Archive tier
az storage blob set-tier \
  --account-name <your-storage-account-name> \
  --container-name demo-container \
  --name test-data/small-file.txt \
  --tier Archive \
  --auth-mode login

# Check the tier of the blob
az storage blob show \
  --account-name <your-storage-account-name> \
  --container-name demo-container \
  --name test-data/small-file.txt \
  --query "properties.blobTier" \
  --output tsv \
  --auth-mode login
```

## Cost Considerations

⚠️ **Important**: This creates billable resources
- Estimated daily cost: $5-20 depending on region
- Clean up immediately after testing
- Monitor costs in Azure portal

## Configuration

The script automatically generates unique storage account names. No manual configuration needed for basic usage.

**Important**: Your actual storage account names for this deployment are:
- **Standard LRS**: `stgdemo73842515801std` through `stgdemo73842515805std`  
- **GRS Accounts**: `stgdemo73842515806grs` through `stgdemo73842515810grs`
- **ZRS Accounts**: `stgdemo73842515811zrs` through `stgdemo73842515815zrs`
- **Premium**: `stgdemo73842515816prm`
- **Legacy V1**: `stgdemo73842515817v1` through `stgdemo73842515820v1`

Use these exact names when running the CLI examples below.

To customize the script, edit variables in `create-storage-demo.sh`:
```bash
RESOURCE_GROUP_NAME="rg-storage-demo"
LOCATION="Sweden Central"
# BASE_NAME is now automatically generated with random suffix
```

## Troubleshooting

**Timing issues**: Script includes automatic retries and wait conditions.

**V1 limitations**: Legacy accounts don't support access tiers or advanced features.

**Permission errors**: Ensure you have Contributor or Owner role on the subscription.

**Region availability**: Some features may not be available in all regions. Use "Sweden Central" or "West Europe" for full support.

**Authentication issues with Azure CLI**:
- If you get "no credentials provided" errors, use `--auth-mode login` for Azure AD authentication
- Alternative: Use `--connection-string` or `--account-key` parameters
- Ensure you're logged in with `az login` before running commands
- For automated scripts, consider using service principals

**Container not found errors**:
- Create containers first using `az storage container create` before uploading blobs
- The demo scripts create sample containers, but you may need to create additional ones for testing

## Learning Objectives

This demo environment helps you understand:

### Primary Concepts
- **Storage Tiers**: Hot, Cool, Archive pricing and use cases
- **Redundancy Options**: Cost vs. protection trade-offs
- **Lifecycle Policies**: Automated cost optimization
- **Feature Costs**: Impact of versioning, soft delete, etc.

### Hands-on Activities
1. **Compare storage costs** across different configurations
2. **Create and test lifecycle policies** for automatic tiering
3. **Analyze cost differences** between redundancy levels
4. **Measure feature impact** on overall storage costs
5. **Practice cost monitoring** using Azure tools

## Additional Resources

### Microsoft Documentation
- [Azure Storage pricing](https://azure.microsoft.com/pricing/details/storage/)
- [Blob lifecycle management](https://docs.microsoft.com/azure/storage/blobs/lifecycle-management-overview)
- [Storage account overview](https://docs.microsoft.com/azure/storage/common/storage-account-overview)
- [Access tiers for blob data](https://docs.microsoft.com/azure/storage/blobs/access-tiers-overview)

### Best Practices
- [Azure Storage cost optimization](https://docs.microsoft.com/azure/storage/common/storage-plan-manage-costs)
- [Blob storage performance tiers](https://docs.microsoft.com/azure/storage/blobs/storage-blob-performance-tiers)
- [Data protection features](https://docs.microsoft.com/azure/storage/blobs/data-protection-overview)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request with improvements or additional demo scenarios.

## Recent Improvements

- **Randomized Naming**: Storage account names now include a random suffix to avoid naming conflicts when running the script multiple times
- **Updated Examples**: All CLI examples updated with actual storage account names from current deployment
- **Better Compatibility**: Improved script compatibility across different environments
- **Unique Deployments**: Each script run creates completely unique storage account names

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: Educational demo only. Clean up resources after testing!
