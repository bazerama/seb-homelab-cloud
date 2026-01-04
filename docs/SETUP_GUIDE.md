# Oracle Cloud Infrastructure Setup Guide

Complete step-by-step guide to get your free K3s cluster running on OCI.

## 📝 Step-by-Step Setup

### 1. Create Oracle Cloud Account

1. Go to https://signup.cloud.oracle.com/
2. Sign up for a **free account** (no credit card charged, truly free!)
3. Verify your email and complete registration
4. Login to https://cloud.oracle.com/

### 2. Generate API Key for Terraform/CDKTF

#### 2.1 Generate SSH Key Pair for API Access

```bash
# Create OCI directory
mkdir -p ~/.oci

# Generate API key (2048 bit RSA)
openssl genrsa -out ~/.oci/oci_api_key.pem 2048

# Set proper permissions
chmod 600 ~/.oci/oci_api_key.pem

# Generate public key
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

# Get fingerprint (you'll need this later)
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c
```

#### 2.2 Upload Public Key to OCI

1. Login to OCI Console: https://cloud.oracle.com/
2. Click your **Profile icon** (top right) → **User Settings**
3. Under **Resources** (left sidebar), click **API Keys**
4. Click **Add API Key**
5. Select **Paste Public Key**
6. Paste contents of `~/.oci/oci_api_key_public.pem`:
   ```bash
   cat ~/.oci/oci_api_key_public.pem
   ```
7. Click **Add**
8. **SAVE THE CONFIGURATION** shown - you'll need these values!

Example configuration shown:
```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaxxxxx
fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
tenancy=ocid1.tenancy.oc1..aaaaaaaxxxxx
region=us-ashburn-1
key_file=~/.oci/oci_api_key.pem
```

### 3. Generate SSH Key for Instance Access

If you don't already have SSH keys:

```bash
# Generate SSH key for accessing compute instances
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "oracle-cloud-k3s"

# Your public key is here:
cat ~/.ssh/id_rsa.pub
```

### 4. Get Required OCIDs

You need several OCIDs (Oracle Cloud Identifiers). Here's how to get them:

#### 4.1 Tenancy OCID

**Option A - From Console:**
1. Click **Profile** (top right) → **Tenancy: <your-tenancy-name>**
2. Copy **OCID** from the Tenancy Information page

**Option B - From API Key config:**
- It's the `tenancy=` value from step 2.2 above

#### 4.2 User OCID

1. Click **Profile** (top right) → **User Settings**
2. Copy **OCID** from the User Information section
3. Or use the `user=` value from API key configuration

#### 4.3 Compartment OCID

For simplicity, use your **tenancy OCID as compartment OCID** (deploys to root compartment).

Or create a dedicated compartment:
1. Menu → **Identity & Security** → **Compartments**
2. Click **Create Compartment**
3. Name it (e.g., "homelab-k3s")
4. Copy the compartment OCID

#### 4.4 Availability Domain

**Option A - Use helper script:**
```bash
# We'll create this script next
./scripts/find-oci-resources.sh
```

**Option B - From Console:**
1. Menu → **Compute** → **Instances**
2. Click **Create Instance**
3. Look at the **Availability Domain** dropdown - note the full name (e.g., `ynwd:US-ASHBURN-AD-1`)
4. Cancel the instance creation

**Option C - Using OCI CLI:**
```bash
# Install OCI CLI first (optional)
oci iam availability-domain list --compartment-id <your-tenancy-ocid>
```

#### 4.5 ARM Image OCID

This is region-specific. We'll create a helper script for this.

**Quick method:**
```bash
# We'll create this script
./scripts/find-arm-image.sh <region> <compartment-ocid>
```

**Manual method:**
1. Menu → **Compute** → **Instances** → **Create Instance**
2. Click **Change Image**
3. Select **Oracle Linux** → **8**
4. Under **Shape**, select **VM.Standard.A1.Flex** (ARM)
5. Look for the image OCID in the selection (starts with `ocid1.image.oc1...`)
6. Cancel the instance creation

### 5. Configure Your Environment

#### Option A: Using terraform.tfvars (Recommended)

```bash
cd /Users/seb/repos/seb-homelab-cloud

# Copy example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

Fill in:
```hcl
tenancy_ocid        = "ocid1.tenancy.oc1..aaaaaaaxxxxx"
user_ocid           = "ocid1.user.oc1..aaaaaaaxxxxx"
fingerprint         = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
private_key_path    = "~/.oci/oci_api_key.pem"
compartment_ocid    = "ocid1.tenancy.oc1..aaaaaaaxxxxx"  # or compartment OCID
region              = "us-ashburn-1"  # your region
availability_domain = "ynwd:US-ASHBURN-AD-1"  # your AD
ssh_public_key_path = "~/.ssh/id_rsa.pub"
arm_image_ocid      = "ocid1.image.oc1.iad.aaaaaaaxxxxx"
```

#### Option B: Using Environment Variables

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Oracle Cloud Infrastructure
export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..aaaaaaaxxxxx"
export TF_VAR_user_ocid="ocid1.user.oc1..aaaaaaaxxxxx"
export TF_VAR_fingerprint="xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
export TF_VAR_private_key_path="$HOME/.oci/oci_api_key.pem"
export TF_VAR_compartment_ocid="ocid1.tenancy.oc1..aaaaaaaxxxxx"
export TF_VAR_region="us-ashburn-1"
export TF_VAR_availability_domain="ynwd:US-ASHBURN-AD-1"
export TF_VAR_ssh_public_key_path="$HOME/.ssh/id_rsa.pub"
export TF_VAR_arm_image_ocid="ocid1.image.oc1.iad.aaaaaaaxxxxx"
```

Then: `source ~/.zshrc`

### 6. Deploy Your Cluster!

```bash
cd /Users/seb/repos/seb-homelab-cloud

# Install dependencies
make install

# Generate CDKTF providers
make get

# Preview what will be created
make plan

# Deploy!
make deploy

# Wait 5-10 minutes for deployment
```

### 7. Access Your K3s Cluster

```bash
# Fetch kubeconfig (using Makefile helper)
make kubeconfig

# Set as active config
export KUBECONFIG=~/.kube/oracle-k3s-config

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

Expected output:
```
NAME            STATUS   ROLES                       AGE   VERSION
k3s-control-1   Ready    control-plane,etcd,master   5m    v1.28.x+k3s1
k3s-worker-1    Ready    <none>                      3m    v1.28.x+k3s1
k3s-worker-2    Ready    <none>                      3m    v1.28.x+k3s1
```

## 🎯 Quick Reference

### Common OCIDs and Where to Find Them

| OCID Type | Where to Find | Format |
|-----------|---------------|--------|
| Tenancy | Profile → Tenancy | `ocid1.tenancy.oc1..aaaaaaa...` |
| User | Profile → User Settings | `ocid1.user.oc1..aaaaaaa...` |
| Compartment | Identity → Compartments | `ocid1.compartment.oc1..aaaaaaa...` |
| Image | Compute → Images | `ocid1.image.oc1.<region>.aaaaaaa...` |

### Available Regions

- `us-ashburn-1` (US East - Ashburn, VA)
- `us-phoenix-1` (US West - Phoenix, AZ)
- `eu-frankfurt-1` (Germany)
- `eu-amsterdam-1` (Netherlands)
- `uk-london-1` (United Kingdom)
- `ap-tokyo-1` (Japan)
- `ap-seoul-1` (South Korea)
- `ap-mumbai-1` (India)
- And more...

Choose the region closest to you for better latency!

## 🔍 Troubleshooting

### "Out of host capacity" error

ARM instances in free tier are **highly sought after**. If you get capacity errors:

1. **Try different availability domains**
   ```bash
   # List all ADs in your region
   oci iam availability-domain list --compartment-id <tenancy-ocid>
   
   # Update terraform.tfvars with different AD
   ```

2. **Try different regions**
   - Some regions have more capacity than others
   - Update `region` and `availability_domain` in config

3. **Try at different times**
   - Off-peak hours (late night/early morning) often have better availability
   - Weekends might have less demand

4. **Keep retrying**
   - Run `make deploy` again after a few hours
   - Capacity is freed up regularly

### "Authorization failed" or "NotAuthenticated"

- Verify your API key is uploaded correctly in OCI Console
- Check fingerprint matches: `openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c`
- Ensure private key has correct permissions: `chmod 600 ~/.oci/oci_api_key.pem`
- Verify user OCID is correct

### Can't SSH into instances

- Wait 2-3 minutes after creation for cloud-init to complete
- Verify SSH key: `ssh-add ~/.ssh/id_rsa`
- Check security list allows SSH from your IP
- Default user is `opc` not `ubuntu`: `ssh opc@<public-ip>`

### K3s not running

```bash
# SSH to control plane
ssh opc@<control-plane-ip>

# Check K3s status
sudo systemctl status k3s

# View K3s logs
sudo journalctl -u k3s -f

# For workers, check k3s-agent
sudo systemctl status k3s-agent
sudo journalctl -u k3s-agent -f
```

## 📚 Helpful Links

- [OCI Free Tier Details](https://www.oracle.com/cloud/free/)
- [OCI Documentation](https://docs.oracle.com/en-us/iaas/Content/home.htm)
- [OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [CDKTF Documentation](https://developer.hashicorp.com/terraform/cdktf)
- [K3s Documentation](https://docs.k3s.io/)

## 🎉 Next Steps

Once your cluster is running:

1. **Deploy ArgoCD** from your `seb-homelab-k8s-iac` repo
2. **Setup LoadBalancer** (OCI free tier includes 1 flexible LB)
3. **Configure DNS** to point to your cluster
4. **Deploy applications** from your homelab setup

Enjoy your free cloud K8s cluster! 🚀

