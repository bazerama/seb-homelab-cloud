# Remote State Setup Guide

## Why Remote State?

Remote state solves the critical problem you just encountered:
- ✅ **Shared state** between local dev and GitHub Actions
- ✅ **State locking** prevents concurrent modifications
- ✅ **Backup** state is stored safely, not just on your laptop
- ✅ **Team collaboration** everyone sees the same infrastructure

## Quick Setup (5 minutes)

### Step 1: Create OCI Object Storage Bucket

```bash
# Run the automated setup script
./scripts/setup-remote-state.sh
```

This will:
1. Create an Object Storage bucket
2. Generate S3-compatible access keys
3. Update `backend.tf` with your namespace
4. Create `.env` with credentials

### Step 2: Enable Remote State

```bash
# Uncomment the backend block in backend.tf
# (The setup script does this for you)

# Migrate existing state to remote
tofu init -migrate-state

# Verify migration
tofu state list
```

### Step 3: Configure GitHub Actions

```bash
# Set the S3 credentials as GitHub secrets
gh secret set AWS_ACCESS_KEY_ID --body "<from-setup-script-output>"
gh secret set AWS_SECRET_ACCESS_KEY --body "<from-setup-script-output>"
gh secret set TF_BACKEND_NAMESPACE --body "<your-oci-namespace>"
```

## Manual Setup (Alternative)

### 1. Create OCI Object Storage Bucket

**Via OCI Console:**
1. Go to: https://cloud.oracle.com/object-storage/buckets
2. Click **Create Bucket**
3. Name: `terraform-state-homelab`
4. Storage Tier: **Standard** (free tier)
5. Enable **Object Versioning** ✅
6. Encryption: **Encrypt using Oracle-managed keys**
7. Click **Create**

**Via OCI CLI:**
```bash
# Get your namespace
NAMESPACE=$(oci os ns get --query 'data' --raw-output)

# Create bucket
oci os bucket create \
  --compartment-id "$TF_VAR_compartment_ocid" \
  --name "terraform-state-homelab" \
  --versioning "Enabled"
```

### 2. Create S3-Compatible Access Keys

**Via OCI Console:**
1. Go to: Profile → User settings → Tokens and keys → Customer Secret Keys
2. Click **Generate Secret Key**
3. Name: `terraform-state-access`
4. **Save the Access Key and Secret Key** (you won't see the secret again!)

**Via OCI CLI:**
```bash
# Create customer secret key
oci iam customer-secret-key create \
  --user-id "$TF_VAR_user_ocid" \
  --display-name "terraform-state-access"
```

### 3. Get Your OCI Namespace

```bash
# Via OCI CLI
oci os ns get

# Or via Console: Object Storage → Buckets → (see namespace in breadcrumb)
```

### 4. Update backend.tf

Edit `backend.tf` and:
1. Replace `<YOUR_NAMESPACE>` with your actual namespace
2. Uncomment the `terraform { backend "s3" { ... } }` block

### 5. Set Environment Variables

Create `.env` (add to `.gitignore`):

```bash
# S3-compatible credentials for OCI Object Storage
AWS_ACCESS_KEY_ID=<your-access-key-id>
AWS_SECRET_ACCESS_KEY=<your-secret-key>
```

These are loaded automatically by `make plan` / `make apply`.

### 6. Migrate State

```bash
# Initialize with remote backend
tofu init -migrate-state

# It will ask: "Do you want to copy existing state to the new backend?"
# Answer: yes

# Verify
tofu state list
```

### 7. Update GitHub Actions

Add secrets to GitHub:

```bash
gh secret set AWS_ACCESS_KEY_ID --body "<your-access-key-id>"
gh secret set AWS_SECRET_ACCESS_KEY --body "<your-secret-key>"
gh secret set TF_BACKEND_NAMESPACE --body "<your-oci-namespace>"
```

Update `.github/workflows/opentofu.yml`:

```yaml
- name: Setup OCI credentials
  run: |
    # ... existing OCI setup ...
    
    # Add S3 credentials for remote state
    echo "AWS_ACCESS_KEY_ID=${{ secrets.AWS_ACCESS_KEY_ID }}" >> $GITHUB_ENV
    echo "AWS_SECRET_ACCESS_KEY=${{ secrets.AWS_SECRET_ACCESS_KEY }}" >> $GITHUB_ENV
```

## Verification

### Test Local Access

```bash
# Should show your resources
tofu state list

# Should show bucket URL
tofu init -backend-config="" 2>&1 | grep bucket
```

### Test GitHub Actions

Push a change and verify the workflow:
1. Uses remote state (check logs for "Initializing the backend...")
2. Can read existing resources
3. No state conflicts

## Troubleshooting

### Error: "Failed to get existing workspaces"

**Cause**: Incorrect endpoint or credentials

**Fix**:
```bash
# Verify namespace
oci os ns get

# Update backend.tf endpoint:
endpoint = "<namespace>.compat.objectstorage.<region>.oraclecloud.com"
```

### Error: "NoSuchBucket"

**Cause**: Bucket doesn't exist or wrong name

**Fix**:
```bash
# List buckets
oci os bucket list --compartment-id "$TF_VAR_compartment_ocid"

# Verify bucket name matches backend.tf
```

### Error: "InvalidAccessKeyId"

**Cause**: Wrong S3 credentials

**Fix**:
1. Go to OCI Console → Profile → User settings → Tokens and keys → Customer Secret Keys
2. Delete old key
3. Generate new key
4. Update `.env` and GitHub secrets

### State Lock Conflicts

**Symptom**: "Error acquiring the state lock"

**Cause**: Previous operation didn't release lock (crash, Ctrl+C, etc.)

**Fix**:
```bash
# Force unlock (use the Lock ID from error message)
tofu force-unlock <LOCK_ID>
```

## Best Practices

### 1. Always Use Remote State for Production

Never commit `terraform.tfstate` to git when using remote state.

### 2. Enable Object Versioning

Protects against accidental state deletion. Enable in bucket settings.

### 3. Rotate Access Keys Regularly

```bash
# Every 90 days
oci iam customer-secret-key create --user-id "$TF_VAR_user_ocid" --display-name "terraform-state-access-$(date +%Y%m)"
# Update secrets
# Delete old key
```

### 4. Use State Locking

S3 backend with DynamoDB (or equivalent) prevents concurrent modifications.
For OCI, state locking is automatic via Object Storage.

### 5. Backup State Periodically

```bash
# Download state to local backup
tofu state pull > "backups/terraform.tfstate.$(date +%Y%m%d)"
```

## Cost

**OCI Free Tier includes:**
- ✅ 10GB Object Storage (more than enough for state files)
- ✅ Unlimited API requests
- ✅ **$0/month** for this setup

## Migration Back to Local (Emergency)

If you need to go back to local state:

```bash
# 1. Comment out backend block in backend.tf
# 2. Re-initialize
tofu init -migrate-state

# 3. Answer 'yes' to copy remote state to local
```

## Next Steps

After setup:
1. ✅ Push this branch
2. ✅ Merge PR
3. ✅ Verify GitHub Actions uses remote state
4. ✅ Celebrate! 🎉 No more state conflicts

## References

- [OCI Object Storage](https://docs.oracle.com/iaas/Content/Object/home.htm)
- [OpenTofu S3 Backend](https://opentofu.org/docs/language/settings/backends/s3/)
- [OCI S3 Compatibility](https://docs.oracle.com/iaas/Content/Object/Tasks/s3compatibleapi.htm)
