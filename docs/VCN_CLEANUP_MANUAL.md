# Manual VCN Cleanup Guide

## 🚨 Issue: VCN Limit Exceeded

**Error:**
```
400-LimitExceeded, The following service limits were exceeded: vcn-count
```

**Free Tier Limit:** 2 VCNs per region

---

## 🌐 Manual Cleanup via OCI Console (Recommended)

### Step 1: View Your VCNs

1. Go to: https://cloud.oracle.com/networking/vcns
2. Make sure you're in the **Sydney (ap-sydney-1)** region (top right)
3. You'll see all your VCNs listed

### Step 2: Identify VCNs to Delete

Look for VCNs that:
- ❌ Are from old/failed deployments
- ❌ Have no instances running
- ❌ Are named differently than your current setup

**Keep:**
- ✅ Any VCN currently in use
- ✅ VCNs with running instances

### Step 3: Delete Unused VCN

For each VCN you want to delete:

1. Click on the VCN name
2. Click **"Terminate"** (top right, red button)
3. The OCI Console will show a wizard:
   - It will list all dependent resources (subnets, route tables, etc.)
   - Check the box to terminate all related resources
4. Confirm termination
5. Wait 2-3 minutes for deletion to complete

### Step 4: Verify Deletion

1. Go back to: https://cloud.oracle.com/networking/vcns
2. Refresh the page
3. Confirm you now have < 2 VCNs

---

## 🔧 Alternative: Reuse Existing VCN

If you have a VCN you want to keep and reuse:

### Option A: Import Existing VCN

```bash
# Get the VCN OCID from the OCI Console
tofu import oci_core_vcn.k3s_vcn <vcn-ocid>
```

### Option B: Modify Configuration

Update `main.tf` to use an existing VCN instead of creating a new one.

---

## ✅ After Cleanup

Once you've freed up VCN capacity:

```bash
# Test that it works
tofu plan

# If successful, apply
tofu apply
```

---

## 📊 Free Tier Limits Reference

| Resource | Free Tier Limit |
|----------|----------------|
| **VCNs** | **2 per region** |
| Subnets | 2 per VCN |
| Route Tables | 2 per VCN |
| Security Lists | 4 per VCN |
| Internet Gateways | 1 per VCN |

---

## 💡 Pro Tips

1. **Use descriptive VCN names** to identify them easily later
2. **Tag your VCNs** with `managed-by = "terraform"` to track which are IaC-managed
3. **Set up budget alerts** (already configured in this repo!) to catch unexpected charges
4. **Free tier VCNs are always $0** - no cost concerns

---

## 🆘 Still Having Issues?

If you're still hitting the VCN limit after cleanup:

1. **Check all regions**: Make sure you're looking at the right region (ap-sydney-1)
2. **Wait for sync**: OCI can take 5-10 minutes to update limits after deletion
3. **Verify termination**: Some VCNs might be stuck in "TERMINATING" state
4. **Contact OCI Support**: If genuinely stuck, open a support ticket

---

## 📝 Prevention

To avoid this in the future:

1. Always run `tofu destroy` when tearing down test environments
2. Manually verify resource deletion in OCI Console after destroy
3. Use consistent naming conventions to track your resources
