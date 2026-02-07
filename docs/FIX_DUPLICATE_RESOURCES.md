# Fix: Duplicate Resources Error

## Problem

Your OpenTofu apply is failing with:

```
Error: 400-LimitExceeded, 1 budgets already exist in target compartment
Error: 400-LimitExceeded, The following service limits were exceeded: vcn-count
```

## Why This Happens

These resources exist from previous deployments (likely from PR #5). OpenTofu doesn't know about them because they're not in the state.

## Quick Fix

### Option 1: Automated Cleanup Check (Recommended)

```bash
./scripts/cleanup-existing-resources.sh
```

This will:
- ✅ Check what resources already exist
- ✅ Show you exact cleanup commands
- ✅ Verify you're ready to deploy

### Option 2: Manual Steps

#### Fix Budget Error

**Option A: Import Existing Budget (Keep it)**

```bash
# 1. Get the budget OCID from OCI Console
# https://cloud.oracle.com/usage/budgets

# 2. Import into state
tofu import oci_budget_budget.free_tier_protection <BUDGET_OCID>

# 3. Try apply again
tofu apply
```

**Option B: Delete Existing Budget (Start fresh)**

```bash
# Via OCI Console
# 1. Go to: https://cloud.oracle.com/usage/budgets
# 2. Click on the budget
# 3. Click "Delete"

# OR via OCI CLI
oci budgets budget delete --budget-id <BUDGET_OCID>
```

#### Fix VCN Error

**You have too many VCNs (max 2 for free tier)**

```bash
# 1. List all VCNs
oci network vcn list --compartment-id <YOUR_COMPARTMENT_OCID>

# 2. Delete VCNs you don't need via OCI Console:
#    https://cloud.oracle.com/networking/vcns
#    - Select VCN
#    - Click "Terminate"
#    - Confirm

# OR via CLI (deletes subnets, gateways, etc. automatically)
oci network vcn delete --vcn-id <VCN_OCID>
```

## After Cleanup

Once you've cleaned up, the GitHub Actions workflow will automatically:
- ✅ Only retry on **capacity errors** (not limit errors)
- ✅ Stop immediately on limit/duplicate errors
- ✅ Show you helpful error messages

## What Changed in PR #6

The auto-retry logic now:
- 🔍 **Checks error type** before retrying
- 🚀 **Only retries** "Out of host capacity" errors
- ❌ **Fails fast** on limit/duplicate errors (so you can fix them)
- 📋 **Shows helpful messages** for each error type

## Prevention

To avoid this in the future:

1. **Always run cleanup script before deploying**:
   ```bash
   ./scripts/cleanup-existing-resources.sh
   ```

2. **Import existing resources** instead of recreating them

3. **Use remote state** (S3/OCI Object Storage) so state is shared across environments

## Need Help?

- Check existing resources: [OCI Console](https://cloud.oracle.com/)
- VCN Limit: [Limits & Quotas](https://cloud.oracle.com/limits)
- Budget Limit: [Usage & Budgets](https://cloud.oracle.com/usage/budgets)
