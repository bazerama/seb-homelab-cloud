# Quick Start - Oracle Cloud K3s Cluster

Get your free K3s cluster running in **under 15 minutes** using OpenTofu!

## ⚡ TL;DR

**100% Always-Free Setup - No charges ever!**

```bash
# 1. Setup OCI account and get API keys (see docs/SETUP_GUIDE.md)

# 2. Run the resource finder script (requires OCI CLI)
./scripts/find-oci-resources.sh

# 3. Deploy! (creates 3 VMs: 4 OCPUs, 24GB RAM - all free!)
tofu init
tofu plan
tofu apply

# Or use Makefile (auto-detects OpenTofu/Terraform):
make init
make deploy

# 4. Get kubeconfig
make kubeconfig
export KUBECONFIG=~/.kube/oracle-k3s-config

# 5. Verify
kubectl get nodes
# Expected: 3 nodes (1 control-plane, 2 workers)
```

**Read [docs/ALWAYS_FREE_TIER.md](docs/ALWAYS_FREE_TIER.md) for complete Always-Free tier details.**

## 📋 Prerequisites Checklist

- [ ] Oracle Cloud Always-Free account created (no time limit!)
- [ ] API key generated and uploaded to OCI
- [ ] SSH key exists at `~/.ssh/id_rsa.pub`
- [ ] OCI CLI installed (optional but recommended)
- [ ] Read [docs/ALWAYS_FREE_TIER.md](docs/ALWAYS_FREE_TIER.md) to understand limits

## 🚀 Step-by-Step

### 1. Create Oracle Cloud Account

**Time: ~5 minutes**

1. Go to https://signup.cloud.oracle.com/
2. Sign up (credit card required for verification but **NOT charged**)
3. Verify email
4. Login to console

### 2. Generate and Upload API Key

**Time: ~3 minutes**

```bash
# Generate API key
mkdir -p ~/.oci
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

# Copy public key
cat ~/.oci/oci_api_key_public.pem
```

Then in OCI Console:
1. Profile → User Settings → API Keys → Add API Key
2. Paste public key
3. Save the configuration shown

### 3. Install OCI CLI (Optional but Helpful)

**Time: ~2 minutes**

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"

# Configure OCI CLI
oci setup config
```

### 4. Find Resources and Configure

**Time: ~2 minutes**

#### Option A: Automated (with OCI CLI)

```bash
cd /Users/seb/repos/seb-homelab-cloud
./scripts/find-oci-resources.sh
# This will create terraform.tfvars for you!
```

#### Option B: Manual

Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in:
- Tenancy OCID (Profile → Tenancy)
- User OCID (Profile → User Settings)
- Fingerprint (from API key upload)
- Region (your preferred region)
- Availability Domain (see docs/SETUP_GUIDE.md)
- ARM Image OCID (run `./scripts/find-arm-image.sh <region> <tenancy-ocid>`)

### 5. Deploy Infrastructure

**Time: ~5-10 minutes**

```bash
# Initialize OpenTofu
tofu init

# Preview what will be created
tofu plan

# Deploy! (takes ~5 minutes)
tofu apply
# Type "yes" when prompted
```

Or use the Makefile (auto-detects OpenTofu or Terraform):

```bash
make init
make plan
make deploy
```

What gets created:
- 1 VCN (Virtual Cloud Network)
- 1 Subnet
- 1 Internet Gateway
- 1 Route Table
- 1 Security List
- 3 ARM compute instances (control plane + 2 workers)
- K3s automatically installed and configured

### 6. Access Your Cluster

**Time: ~1 minute**

```bash
# Fetch kubeconfig from control plane
make kubeconfig

# Set as active kubeconfig
export KUBECONFIG=~/.kube/oracle-k3s-config

# Verify cluster is ready
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

## 🎉 You're Done!

Your free K3s cluster is now running!

### Next Steps

1. **Deploy ArgoCD** from your `seb-homelab-k8s-iac` repo
2. **Setup LoadBalancer** (free tier includes 1 flexible LB)
3. **Configure storage** (block volumes up to 200GB total free)
4. **Deploy your applications**

## 🔍 Useful Commands

```bash
# Check version
make version
# or: tofu version

# View deployed resources
make status
# or: tofu output

# SSH into nodes
make ssh-control
make ssh-worker-1
make ssh-worker-2

# Show current state
make show
# or: tofu show

# Destroy everything (WARNING: deletes all resources)
make destroy
# or: tofu destroy

# Redeploy after changes
make deploy
# or: tofu apply
```

## 🐛 Common Issues

### "Out of host capacity"

ARM instances are popular! Try:
1. Different availability domain
2. Different region
3. Deploy at off-peak hours
4. Keep retrying - capacity frees up regularly

### Can't connect to instances

- Wait 2-3 minutes for cloud-init to complete
- Verify security list allows SSH from your IP
- Check you're using user `opc`: `ssh opc@<ip>`

### K3s not starting

```bash
# SSH to instance
make ssh-control

# Check status
sudo systemctl status k3s
sudo journalctl -u k3s -f
```

## 📚 More Information

- **Complete setup guide**: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
- **Architecture details**: [README.md](README.md)
- **Troubleshooting**: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md#troubleshooting)

## 💰 Cost

**$0/month** with Oracle Cloud Free Tier!

Includes:
- 4 OCPUs + 24GB RAM (ARM)
- 200GB block storage
- 10TB monthly egress
- 1 flexible load balancer
- **Forever free!**

---

Enjoy your free Kubernetes cluster! 🚀
