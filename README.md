# Seb's Homelab - Oracle Cloud Infrastructure

This repository contains OpenTofu (Terraform-compatible) code to deploy a K3s Kubernetes cluster on Oracle Cloud Infrastructure (OCI) using the **Always Free tier**.

> **Note:** This uses [OpenTofu](https://opentofu.org/), the open-source Terraform alternative. It's fully compatible with Terraform if you prefer that.

## 🎯 What You Get (100% Always-Free Tier)

- **3 ARM-based compute instances** (Oracle Ampere A1 - VM.Standard.A1.Flex)
  - 1x Control Plane (2 OCPU, 12GB RAM, 50GB storage)
  - 2x Workers (1 OCPU, 6GB RAM, 50GB storage each)
  - **Total: 4 OCPUs, 24GB RAM, 150GB storage** (within free tier limits)
- **K3s Kubernetes cluster** (lightweight Kubernetes)
- **Public IPs** for all nodes
- **Automatic K3s installation** via cloud-init
- **$0/month** - completely free, forever!

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│              Oracle Cloud Free Tier                 │
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │           VCN (10.0.0.0/16)                  │  │
│  │                                               │  │
│  │  ┌─────────────────────────────────────────┐ │  │
│  │  │    Subnet (10.0.1.0/24)                 │ │  │
│  │  │                                          │ │  │
│  │  │  ┌──────────────┐                       │ │  │
│  │  │  │ k3s-control-1│ (2 OCPU, 12GB)        │ │  │
│  │  │  │ Public IP    │                       │ │  │
│  │  │  └──────────────┘                       │ │  │
│  │  │                                          │ │  │
│  │  │  ┌──────────────┐  ┌──────────────┐    │ │  │
│  │  │  │ k3s-worker-1 │  │ k3s-worker-2 │    │ │  │
│  │  │  │ (1 OCPU, 6GB)│  │ (1 OCPU, 6GB)│    │ │  │
│  │  │  └──────────────┘  └──────────────┘    │ │  │
│  │  │                                          │ │  │
│  │  └─────────────────────────────────────────┘ │  │
│  │                                               │  │
│  └───────────────────────────────────────────────┘  │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## ⚠️ Common Issue: "Out of host capacity"

Oracle Cloud Free Tier ARM instances are in high demand. If you see "Out of host capacity" errors:

1. **Run the capacity checker:** `./scripts/check-oci-capacity.sh`
2. **Try different availability domains** in your region
3. **Try different times** (early morning/late night work best)
4. **See full troubleshooting guide:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## 📋 Prerequisites

1. **Oracle Cloud Account** (free tier)
2. **OpenTofu** (v1.6+): [Install OpenTofu](https://opentofu.org/docs/intro/install/)
   - Or use **Terraform** (v1.6+) if you prefer: [Install Terraform](https://developer.hashicorp.com/terraform/downloads)
3. **OCI CLI** (optional, but helpful): Follow [OCI CLI installation](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)

### Installing OpenTofu

**macOS (Homebrew):**
```bash
brew install opentofu
```

**Linux:**
```bash
# Snap
snap install --classic opentofu

# Or download from https://opentofu.org/docs/intro/install/
```

**Verify installation:**
```bash
tofu version
```

## 🚀 Setup Instructions

### Step 1: OCI API Key Setup

1. Login to [Oracle Cloud Console](https://cloud.oracle.com/)
2. Go to **Profile** (top right) → **User Settings**
3. Under **Resources**, click **API Keys** → **Add API Key**
4. Download the private key (save as `~/.oci/oci_api_key.pem`)
5. Copy the configuration shown - you'll need these values

### Step 2: Find Required OCIDs

Run these commands or get from console:

```bash
# Tenancy OCID
oci iam tenancy get --tenancy-id <from-config>

# User OCID (from API key setup page)
echo "Already have this from Step 1"

# Compartment OCID (can use tenancy OCID for root compartment)
oci iam compartment list --all

# Availability Domain
oci iam availability-domain list --compartment-id <tenancy-ocid>

# ARM Image OCID (Oracle Linux 8 ARM)
oci compute image list \
  --compartment-id <tenancy-ocid> \
  --operating-system "Oracle Linux" \
  --operating-system-version "8" \
  --shape "VM.Standard.A1.Flex" \
  --sort-by TIMECREATED \
  --sort-order DESC \
  --limit 1
```

### Step 3: Configure Variables

```bash
cd /Users/seb/repos/seb-homelab-cloud

# Copy example config
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

Or use environment variables:

```bash
export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..xxx"
export TF_VAR_user_ocid="ocid1.user.oc1..xxx"
export TF_VAR_fingerprint="xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
export TF_VAR_private_key_path="~/.oci/oci_api_key.pem"
export TF_VAR_region="us-ashburn-1"
export TF_VAR_compartment_ocid="ocid1.tenancy.oc1..xxx"
export TF_VAR_availability_domain="ynwd:US-ASHBURN-AD-1"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
export TF_VAR_arm_image_ocid="ocid1.image.oc1.iad.xxx"
```

### Step 4: Deploy!

```bash
# Initialize OpenTofu
tofu init

# View what will be created
tofu plan

# Deploy the cluster
tofu apply

# This will:
# 1. Validate Always-Free tier limits
# 2. Create VCN, subnet, security groups
# 3. Create 3 ARM instances
# 4. Install K3s automatically
# 5. Output public IPs and kubeconfig command
```

Or use the Makefile (automatically uses OpenTofu or Terraform):
```bash
make init
make plan
make deploy
```

### Step 5: Access Your Cluster

```bash
# Get kubeconfig from control plane (IP from output)
ssh opc@<control-plane-public-ip> sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/oracle-k3s-config

# Replace localhost with public IP
sed -i "s/127.0.0.1/<control-plane-public-ip>/g" ~/.kube/oracle-k3s-config

# Use it
export KUBECONFIG=~/.kube/oracle-k3s-config
kubectl get nodes
```

## 📊 Oracle Ampere Always-Free Tier Limits

**What Oracle Provides (per tenancy):**

| Resource | Free Tier Limit | This Setup Uses | Status |
|----------|----------------|-----------------|---------|
| ARM OCPUs | 4 | 4 (100%) | ✅ Maxed out |
| ARM Memory | 24 GB | 24 GB (100%) | ✅ Maxed out |
| ARM Instances | Up to 4 VMs | 3 VMs | ✅ Within limit |
| Boot Storage | 200 GB | 150 GB (75%) | ✅ Within limit |
| Public IPs | 2 reserved + ephemeral | 3 ephemeral | ✅ Within limit |
| Outbound Transfer | 10 TB/month | As needed | ✅ More than enough |

**Important Notes:**
- ✅ All instances use **VM.Standard.A1.Flex** (Always-Free eligible shape)
- ✅ Configuration is 100% within Always-Free tier limits
- ✅ No charges will ever be incurred with this setup
- ⚠️ This uses ALL available ARM resources (no room for more ARM VMs)
- 💡 Free tier also includes 2× x86 VMs (VM.Standard.E2.1.Micro) but they're too weak to be useful

## 🪝 Pre-commit Hooks

This repository uses pre-commit hooks to ensure code quality!

**Setup (one-time):**
```bash
./scripts/setup-pre-commit.sh
```

**What gets checked:**
- ✅ OpenTofu formatting (`tofu fmt`)
- ✅ OpenTofu validation
- ✅ Secret detection (gitleaks)
- ✅ Shell script linting (shellcheck)
- ✅ Markdown linting
- ✅ YAML validation
- ✅ No direct commits to main

**Manual run:**
```bash
pre-commit run --all-files
```

## 🤖 GitHub Actions CI/CD

This repository includes automated OpenTofu deployment via GitHub Actions!

**Features:**
- ✅ Automatic validation on PRs
- ✅ Plan preview in PR comments
- ✅ Auto-apply on main branch (with approval)
- ✅ Manual plan/apply/destroy

**Setup:** See [`.github/workflows/README.md`](.github/workflows/README.md) for configuration instructions.

**Helper Script:**
```bash
./scripts/setup-github-secrets.sh
# Shows all values to add to GitHub Secrets
```

## 🔧 Management Commands

```bash
# Check version (shows OpenTofu or Terraform)
make version

# Initialize OpenTofu
make init

# Format .tf files
make fmt

# Validate configuration
make validate

# View changes
make plan

# Deploy infrastructure
make deploy

# Show current state
make show

# Show deployed resources
make status

# Destroy everything
make destroy
```

Or use OpenTofu directly:
```bash
tofu init
tofu plan
tofu apply
tofu destroy
```

## 📝 Next Steps

After deployment, you can:

1. **Deploy ArgoCD** from your `seb-homelab-k8s-iac` repo
2. **Setup ingress** with Gateway API or nginx
3. **Configure Longhorn** for persistent storage
4. **Point applications** to this new cluster

## 🔐 Security Notes

- Default security list allows SSH (22), K8s API (6443), HTTP (80), HTTPS (443)
- **Restrict SSH access** by modifying the security list in `main.ts`
- Change `source: "0.0.0.0/0"` to your IP for SSH rule
- K3s token is randomly generated and output (sensitive)

## 💡 Tips

- **Monitoring**: Free tier includes OCI Monitoring
- **Backups**: Setup OCI Object Storage (10GB free) for backups
- **Load Balancer**: Free tier includes 1 flexible load balancer (10Mbps)
- **ARM Performance**: Ampere A1 CPUs are excellent for containerized workloads!

## 🐛 Troubleshooting

### Can't create instance - capacity error
```bash
# Try different availability domains
oci iam availability-domain list --compartment-id <tenancy-ocid>
# Update terraform.tfvars with a different AD
```

### SSH connection refused
```bash
# Wait 2-3 minutes after creation for cloud-init to complete
# Check instance console from OCI web UI
```

### K3s not starting
```bash
# SSH to instance and check logs
ssh opc@<instance-ip>
sudo journalctl -u k3s -f  # or k3s-agent for workers
```

## 📚 Links

- [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- [CDKTF Documentation](https://developer.hashicorp.com/terraform/cdktf)
- [K3s Documentation](https://docs.k3s.io/)
- [OCI Provider for Terraform](https://registry.terraform.io/providers/oracle/oci/latest/docs)

## 🎉 What's Next?

Check out the main K8s IaC repo: [seb-homelab-k8s-iac](../seb-homelab-k8s-iac)
