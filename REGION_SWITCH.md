# Switching to US East (Ashburn) Region

## Why Switch Regions?

Sydney (ap-sydney-1) has very limited ARM capacity. US East (us-ashburn-1) typically has much better availability for Always Free ARM instances.

## Steps to Complete the Switch

### Step 1: Find the ARM Image OCID for us-ashburn-1

You have three options:

#### Option A: Use OCI CLI (Recommended if configured)

```bash
./scripts/find-arm-image.sh us-ashburn-1
```

#### Option B: Use OCI Console (Easiest)

1. Log into OCI Console: https://cloud.oracle.com/
2. Go to: **Compute** → **Instances** → **Create Instance**
3. Click **"Change Image"**
4. Select **"Canonical Ubuntu"** → **"22.04 Minimal aarch64"**
5. Copy the **Image OCID** (it will look like: `ocid1.image.oc1.iad.aaaaaa...`)

#### Option C: Use Oracle's Image Catalog

1. Visit: https://docs.oracle.com/iaas/images/
2. Change region filter to: **US East (Ashburn)**
3. Search for: **"Canonical Ubuntu 22.04"**
4. Look for the **aarch64** (ARM) version
5. Copy the OCID

### Step 2: Update terraform.tfvars

Open `terraform.tfvars` and update the `arm_image_ocid`:

```hcl
arm_image_ocid = "ocid1.image.oc1.iad.aaaaaa..."  # Replace with actual OCID from Step 1
```

The region and availability_domain have already been updated to:
- `region = "us-ashburn-1"`
- `availability_domain = "zkJl:US-ASHBURN-AD-1"`

**Note**: If the AD doesn't work, try these alternatives for us-ashburn-1:
- `zkJl:US-ASHBURN-AD-1`
- `zkJl:US-ASHBURN-AD-2`  
- `zkJl:US-ASHBURN-AD-3`

### Step 3: Update GitHub Secrets (if using GitHub Actions)

If you're using the GitHub Actions workflow, update the secrets:

```bash
./scripts/set-github-secrets.sh
```

This will update:
- `OCI_REGION` → us-ashburn-1
- `OCI_AVAILABILITY_DOMAIN` → zkJl:US-ASHBURN-AD-1
- `OCI_ARM_IMAGE_OCID` → (new value from Step 1)

### Step 4: Test the Configuration

```bash
# Validate
tofu validate

# Plan (should work without capacity errors)
tofu plan
```

### Step 5: Deploy

```bash
tofu apply
```

US East typically has **much better capacity**, so this should succeed!

## Important Notes

### Network Latency
- US East will have higher latency if you're in Australia (~180-200ms vs ~10-20ms)
- This is a trade-off for getting capacity
- Once deployed, you can try switching back to Sydney later

### Storage
- Your Block Volumes and Object Storage will be in us-ashburn-1
- Each region has separate storage quotas

### Costs
- Still 100% free on Always Free tier
- Network egress is free up to 10TB/month per region

## Verification

After deployment, verify your instances are in the correct region:

```bash
# Check instances
tofu output

# Or via OCI Console
# Go to: Compute → Instances
# Check the "Region" dropdown shows "US East (Ashburn)"
```

## Rollback (Optional)

If you want to switch back to Sydney later (when capacity is available):

1. Update `terraform.tfvars`:
   - `region = "ap-sydney-1"`
   - `availability_domain = "JYNt:AP-SYDNEY-1-AD-1"`
   - `arm_image_ocid = "ocid1.image.oc1.ap-sydney-1.aaaaaaaavd6pyh743377ohug5wxn77c2tomo3fh3hslna7dx5ktpk35llt7q"`

2. Destroy current infrastructure:
   ```bash
   tofu destroy
   ```

3. Redeploy in Sydney:
   ```bash
   tofu apply
   ```

## Success Tips

- US East deployment usually succeeds on first try
- If it fails, try different ADs (AD-2 or AD-3)
- Best times to deploy: Any time (US East has good capacity 24/7)

Good luck! 🚀
