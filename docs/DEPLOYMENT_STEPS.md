# OCI Deployment Steps - Incremental Approach

## What We've Done

✅ **Branch Created**: `fix/oci-capacity-free-tier`

✅ **Changes Committed**:
1. Added comprehensive troubleshooting guide (`docs/TROUBLESHOOTING.md`)
2. Added capacity checker script (`scripts/check-oci-capacity.sh`)
3. Updated README with capacity warning
4. Modified `main.tf` to deploy incrementally (control plane only first)

## Current Status

The `main.tf` is now configured to deploy **only the control plane** (1 node, 2 OCPUs, 12GB RAM) to avoid the "Out of host capacity" error.

## Next Steps

### Step 1: Push Your Changes

```bash
git push origin fix/oci-capacity-free-tier
```

### Step 2: Deploy Control Plane

Run the apply command:

```bash
tofu apply
```

This will create:
- VCN and networking
- Security lists
- 1 control plane node (k3s-control-1)

**Expected time**: 5-10 minutes

### Step 3: Add Worker Nodes (One at a Time)

Once the control plane is successfully deployed:

#### Add Worker 1:

1. Edit `main.tf` lines 16-22, uncomment the first worker:

```hcl
{
  name       = "k3s-worker-1"
  role       = "worker"
  ocpus      = 1
  memory_gb  = 6
  storage_gb = 50
},
```

2. Run:

```bash
tofu apply
```

#### Add Worker 2:

1. Edit `main.tf` lines 23-29, uncomment the second worker:

```hcl
{
  name       = "k3s-worker-2"
  role       = "worker"
  ocpus      = 1
  memory_gb  = 6
  storage_gb = 50
}
```

2. Run:

```bash
tofu apply
```

### Step 4: Verify Cluster

Once all nodes are deployed, SSH into the control plane:

```bash
# Get the control plane IP from tofu output
tofu output

# SSH in
ssh ubuntu@<control-plane-ip>

# Check K3s status
sudo systemctl status k3s
sudo kubectl get nodes
```

## Alternative: Try Different Availability Domain

If the control plane deployment still fails with capacity errors, try a different availability domain:

### Option A: Use the Checker Script

```bash
./scripts/check-oci-capacity.sh
```

This will list all available ADs in your region.

### Option B: Manual Check

1. List ADs (if you have OCI CLI configured):

```bash
oci iam availability-domain list \
  --compartment-id "ocid1.tenancy.oc1..aaaaaaaauya6gand6lmc34totxwf7puiikejbih3dquyipsr22ldqe7g3hxa"
```

2. Update `terraform.tfvars` with a different AD from the list

3. Run `tofu apply` again

## Alternative: Try Different Region

If Sydney has no capacity, consider these regions with typically better availability:

1. **us-ashburn-1** (US East)
2. **eu-frankfurt-1** (EU Central)
3. **ap-mumbai-1** (India)

To change regions:

1. Update `region` in `terraform.tfvars`
2. Find the ARM image OCID for the new region (see `docs/SETUP.md`)
3. Update `arm_image_ocid` in `terraform.tfvars`
4. Update `availability_domain` for the new region

## Troubleshooting

For detailed troubleshooting, see:
- `docs/TROUBLESHOOTING.md` - Comprehensive guide
- `README.md` - Quick capacity tips

## Tips for Success

1. **Best Times to Deploy**:
   - Early morning (2-6 AM local time)
   - Late night (11 PM - 2 AM)
   - Weekdays vs weekends

2. **Retry Strategy**:
   - If it fails, wait 15-30 minutes and try again
   - Oracle's capacity changes frequently

3. **Monitor Progress**:
   - Watch the OCI Console while deploying
   - Check for any error messages in real-time

## After Successful Deployment

1. Create a PR from `fix/oci-capacity-free-tier` to `main`
2. Document any specific ADs or times that worked for you
3. Consider adding the successful configuration to the README

Good luck! 🚀
