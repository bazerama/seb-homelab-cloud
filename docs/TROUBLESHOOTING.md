# Troubleshooting Guide

## Common Issues

### 1. "Out of host capacity" Error

**Error Message:**
```
Error: 500-InternalError, Out of host capacity.
```

**Cause:**
Oracle Cloud Free Tier has limited ARM capacity, and it's often exhausted in popular regions/availability domains.

**Solutions (in order of effectiveness):**

#### Option A: Try Different Availability Domains (Fastest)

1. Run the capacity checker script:
   ```bash
   ./scripts/check-oci-capacity.sh
   ```

2. Update `terraform.tfvars` with a different availability domain from the list

3. Run `tofu plan` again

#### Option B: Try Different Regions

Some regions have better capacity than others. Popular regions with good capacity:
- `us-ashburn-1` (US East) - Usually good capacity
- `eu-frankfurt-1` (EU Central) - Usually good capacity  
- `ap-mumbai-1` (India) - Often has capacity
- `uk-london-1` (UK) - Usually good capacity

To change regions:
1. Update `region` in `terraform.tfvars`
2. Find the ARM image OCID for the new region (see SETUP.md)
3. Update `arm_image_ocid` in `terraform.tfvars`
4. List availability domains: `oci iam availability-domain list --compartment-id <tenancy-ocid>`
5. Update `availability_domain` in `terraform.tfvars`

#### Option C: Deploy Incrementally

Instead of deploying all 3 nodes at once, deploy them one at a time:

1. **Deploy control plane only first:**
   
   Edit `main.tf` and temporarily comment out the worker nodes in the `locals.nodes` block:
   ```hcl
   locals {
     nodes = [
       {
         name       = "k3s-control-1"
         role       = "control-plane"
         ocpus      = 2
         memory_gb  = 12
         storage_gb = 50
       },
       # Temporarily commented - add back one at a time
       # {
       #   name       = "k3s-worker-1"
       #   ...
       # },
     ]
   }
   ```

2. Run `tofu apply` to create just the control plane

3. Once successful, uncomment one worker, apply again

4. Repeat for the second worker

#### Option D: Retry at Different Times

Oracle's capacity changes throughout the day. Try:
- Early morning (2-6 AM local time)
- Late night (11 PM - 2 AM local time)
- Weekdays vs weekends

#### Option E: Use Smaller Instances Initially

Start with smaller instances to get a foothold, then resize:

1. Temporarily reduce OCPUs/memory in `locals.nodes`:
   ```hcl
   {
     name       = "k3s-control-1"
     ocpus      = 1  # Reduced from 2
     memory_gb  = 6  # Reduced from 12
     ...
   }
   ```

2. Once instances are created, you can resize them later via OCI Console

### 2. Invalid Authentication Error

**Error Message:**
```
Error: 401-NotAuthenticated
```

**Solutions:**
1. Verify your API key fingerprint matches in OCI Console
2. Ensure `~/.oci/oci_api_key.pem` is readable: `chmod 600 ~/.oci/oci_api_key.pem`
3. Check GitHub Secrets are correctly set (for CI/CD)

### 3. Terraform State Lock Issues

**Error Message:**
```
Error acquiring the state lock
```

**Solutions:**
1. If working locally, ensure no other `tofu` commands are running
2. If using remote state, check for stale locks in your backend
3. Force unlock (use with caution): `tofu force-unlock <LOCK_ID>`

### 4. Pre-commit Hook Failures

See the main README.md for pre-commit troubleshooting.

## Getting Help

1. **Check OCI Service Health:**
   - https://ocistatus.oraclecloud.com/

2. **Oracle Cloud Free Tier Docs:**
   - https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm

3. **Community Resources:**
   - r/oraclecloud subreddit
   - Oracle Cloud Infrastructure Community Forums

## Useful Commands

```bash
# List availability domains
oci iam availability-domain list --compartment-id <compartment-ocid>

# List available ARM shapes
oci compute shape list --compartment-id <compartment-ocid> \
  --availability-domain <ad-name> \
  | grep -i ampere

# Check current capacity (requires OCI CLI)
oci limits resource-availability get \
  --service-name compute \
  --limit-name vm-standard-a1-core-count \
  --compartment-id <compartment-ocid> \
  --availability-domain <ad-name>
```
