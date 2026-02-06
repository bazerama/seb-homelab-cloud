# Oracle Cloud Ampere Always-Free Tier - Complete Guide

## 🎯 What is Always-Free?

Oracle Cloud offers a **genuinely free tier** that never expires (unlike AWS/GCP 12-month trials). This includes powerful ARM-based compute resources perfect for running Kubernetes.

## 📊 Always-Free Tier Limits (Per Tenancy)

### Compute - Ampere A1 (ARM)

| Resource | Limit | Notes |
|----------|-------|-------|
| **Shape** | VM.Standard.A1.Flex | ARM64 Ampere A1 processors |
| **OCPUs** | Up to 4 total | Across ALL ARM instances |
| **Memory** | Up to 24 GB total | Across ALL ARM instances |
| **Instances** | Up to 4 VMs | Practical limit for ARM |
| **Boot Volumes** | 200 GB total | Can split however you want |
| **Instance Config** | Flexible | Any combo up to 4 OCPU / 24GB |

### Compute - x86 (AMD/Intel)

| Resource | Limit | Notes |
|----------|-------|-------|
| **Shape** | VM.Standard.E2.1.Micro | x86_64 processors |
| **Instances** | 2 VMs | Forever free |
| **OCPUs per VM** | 1/8 OCPU | Very limited |
| **Memory per VM** | 1 GB | Too small for K8s |

**Verdict on x86 VMs:** Not useful for K8s - stick with ARM!

### Storage

| Resource | Limit | Notes |
|----------|-------|-------|
| **Block Volumes** | 200 GB total | For all boot + additional volumes |
| **Block Volume Performance** | Balanced | Good for most workloads |
| **Object Storage** | 10 GB | For backups, artifacts |
| **Archive Storage** | 10 GB | Cold storage |

### Networking

| Resource | Limit | Notes |
|----------|-------|-------|
| **Outbound Transfer** | 10 TB/month | More than enough! |
| **Inbound Transfer** | Unlimited | Free |
| **Public IPs (reserved)** | 2 IPs | Static IPs |
| **Public IPs (ephemeral)** | Unlimited | Assigned to instances |
| **Load Balancer** | 1 flexible LB | 10 Mbps bandwidth |
| **VCNs** | Unlimited | Virtual networks |

### Other Services

| Resource | Limit | Notes |
|----------|-------|-------|
| **Autonomous Database** | 2 databases | 1 OCPU, 20GB each |
| **NoSQL Database** | 3 tables | 133M reads/month, 133M writes/month |
| **Monitoring** | 500M ingestion datapoints | More than enough |
| **Notifications** | 1000 emails/month | For alerts |
| **Logging** | 10 GB | For application logs |

## ✅ Our Configuration (100% Always-Free)

### What We Deploy

```
┌─────────────────────────────────────────────────┐
│  Oracle Cloud Always-Free Tier                  │
│                                                  │
│  Total Resources Used:                          │
│  ✅ 4 OCPUs / 4 available (100%)                │
│  ✅ 24 GB RAM / 24 GB available (100%)          │
│  ✅ 3 VMs / 4 practical limit (75%)             │
│  ✅ 150 GB storage / 200 GB available (75%)     │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  k3s-control-1                             │ │
│  │  Shape: VM.Standard.A1.Flex                │ │
│  │  OCPUs: 2 (50% of free tier)               │ │
│  │  Memory: 12 GB (50% of free tier)          │ │
│  │  Storage: 50 GB                            │ │
│  │  Role: K3s Server (control plane + etcd)  │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  k3s-worker-1                              │ │
│  │  Shape: VM.Standard.A1.Flex                │ │
│  │  OCPUs: 1 (25% of free tier)               │ │
│  │  Memory: 6 GB (25% of free tier)           │ │
│  │  Storage: 50 GB                            │ │
│  │  Role: K3s Agent (worker)                  │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  k3s-worker-2                              │ │
│  │  Shape: VM.Standard.A1.Flex                │ │
│  │  OCPUs: 1 (25% of free tier)               │ │
│  │  Memory: 6 GB (25% of free tier)           │ │
│  │  Storage: 50 GB                            │ │
│  │  Role: K3s Agent (worker)                  │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Why This Configuration?

1. **Maximum Resource Usage** - Uses 100% of free ARM compute
2. **Balanced** - Control plane has 2x resources of workers
3. **Room to Grow** - Can add 1 more VM if needed (for 4 total)
4. **Storage Reserve** - Leaves 50GB for additional block volumes

## 🔒 Guaranteed Always-Free

### How to Ensure You Stay Free

1. **Use ONLY VM.Standard.A1.Flex shape** ✅
   - This is the Always-Free ARM shape
   - Our CDKTF code enforces this

2. **Stay within 4 OCPUs + 24GB RAM total** ✅
   - Our configuration uses exactly 4 + 24GB
   - CDKTF code validates this at deploy time

3. **Keep boot volumes under 200GB total** ✅
   - We use 150GB (3× 50GB)
   - 50GB buffer remaining

4. **Don't upgrade to paid services** ⚠️
   - OCI will WARN you before charging
   - Never click "Upgrade to paid" by accident

5. **Monitor your usage** ✅
   - OCI Console shows free tier usage
   - Set up budget alerts (free)

### Oracle's Guarantee

From Oracle's official documentation:

> "Always Free services are available for an unlimited time. Always Free resources are provided in addition to any service credits you receive, and you can keep using them even after your credits expire."

**Translation:** It's actually free forever!

## ⚠️ Common Misconceptions

### Myth: "Oracle will charge me eventually"
**FALSE** - Always-Free is permanent. You only pay if you explicitly create paid resources.

### Myth: "I need a credit card, so they'll charge me"
**TRUE that you need a card** - But only for identity verification. They will NOT charge you for Always-Free resources.

### Myth: "Free tier expires after 12 months"
**FALSE** - That's AWS/GCP. Oracle's Always-Free never expires.

### Myth: "The performance will be throttled"
**FALSE** - Always-Free resources are full performance, same as paid.

### Myth: "They can take it away anytime"
**MOSTLY FALSE** - Oracle has committed to Always-Free. Only exception: Account inactivity (no login for extended periods).

## 🎛️ Alternative Configurations (All Free)

### Option 1: Current (Balanced - Recommended)
```
- 1× Control (2 OCPU, 12GB) 
- 2× Workers (1 OCPU, 6GB each)
- Total: 3 VMs, 4 OCPU, 24GB
- Good for: General homelab use
```

### Option 2: High Availability Control Plane
```
- 3× Control (1 OCPU, 6GB each)
- 1× Worker (1 OCPU, 6GB)
- Total: 4 VMs, 4 OCPU, 24GB
- Good for: Production HA control plane
- Note: Uses all 4 VM slots
```

### Option 3: Maximum Workers
```
- 1× Control (1 OCPU, 6GB)
- 3× Workers (1 OCPU, 6GB each)
- Total: 4 VMs, 4 OCPU, 24GB
- Good for: Maximum pod capacity
- Warning: Control plane under-resourced
```

### Option 4: Single Node (Dev/Test)
```
- 1× All-in-One (4 OCPU, 24GB)
- Total: 1 VM, 4 OCPU, 24GB
- Good for: Testing, development, learning
- Simplest setup
```

## 📈 What Can You Run?

With 4 OCPU + 24GB RAM, you can comfortably run:

### ✅ Definitely Works Well
- ArgoCD
- Small-medium web applications
- Microservices (5-10 services)
- CI/CD pipelines (GitLab Runner)
- Tandoor Recipes + Postgres
- OAuth2 Proxy
- Sealed Secrets
- Cert-Manager
- Ingress controllers
- Prometheus (small retention)
- Grafana
- Vault (small scale)

### ⚠️ Works But Resource-Limited
- Elasticsearch (single node, limited indices)
- GitLab CE (works but tight)
- Nextcloud
- Larger databases (careful with memory)

### ❌ Probably Won't Work Well
- Elasticsearch cluster (multi-node)
- Heavy ML/AI workloads
- Large databases (> 50GB)
- Resource-intensive build systems
- Mining/crypto (also against ToS)

## 🚨 How to Avoid Accidental Charges

### 1. Set Up Cost Management

```bash
# In OCI Console:
# 1. Navigation → Billing & Cost Management → Budgets
# 2. Create Budget
#    - Amount: $1 (will alert if you ever get charged)
#    - Alert at: 100% of budget
# 3. Add your email for alerts
```

### 2. Enable Cost Tracking Tags

```bash
# All our resources are tagged with:
freeformTags: {
  tier: "always-free",
  managed-by: "cdktf",
}
```

### 3. Regular Audits

```bash
# Check your current resources:
oci compute instance list --compartment-id <your-compartment> \
  --query 'data[*].{Name:"display-name", Shape:shape, State:"lifecycle-state"}'

# Verify shapes (should all be VM.Standard.A1.Flex):
# If you see any other shape, investigate!
```

### 4. Review Monthly

- Check OCI Console → Billing → Cost Analysis
- Should always show $0.00
- If not, identify what's causing charges

## 📞 If You Ever Get Charged

1. **Don't panic** - Small charges ($0.01) sometimes appear and get credited
2. **Check what resource** - OCI Console → Billing → Cost Analysis
3. **Verify it's not a reservation** - Some services require $0.01 holds
4. **Contact support** - OCI support is free and responsive
5. **Delete paid resources** - If you accidentally created them

## 🔐 Account Security

### Keep Your Account Active

Oracle may reclaim inactive accounts:
- **Login at least once every 90 days** (to be safe)
- Set a calendar reminder
- Or setup monitoring that keeps it "active"

### Secure Your Account

```bash
# 1. Enable MFA (Multi-Factor Authentication)
# OCI Console → Profile → User Settings → Auth Tokens

# 2. Use strong API keys
# Already done with 2048-bit RSA keys

# 3. Limit API key permissions
# Use compartments to restrict access

# 4. Regular key rotation
# Rotate API keys every 90 days (best practice)
```

## 💡 Pro Tips

### 1. Use All Available Resources

Don't leave free resources unused:
- We use 4/4 OCPUs ✅
- We use 24/24 GB RAM ✅
- We use 150/200 GB storage (75%)
- Consider using remaining 50GB for persistent volumes

### 2. Leverage Other Free Services

```bash
# Object Storage (10GB free)
# - Perfect for backups
# - K8s YAML manifests
# - Docker registry

# OCI Logging (10GB free)
# - Centralized logs
# - Better than running ELK stack

# OCI Monitoring (500M datapoints)
# - Instance metrics
# - Custom metrics
# - Better than running Prometheus long-term storage
```

### 3. Combine with Other Free Tiers

```bash
# Cloudflare (free)
# - DNS management
# - CDN
# - DDoS protection
# - SSL certificates

# GitHub Actions (free for public repos)
# - CI/CD
# - 2000 minutes/month for private repos

# Docker Hub (free)
# - Container registry
# - Unlimited public images
```

## 📚 Official Resources

- [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- [Always Free Resources Documentation](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [Pricing Calculator](https://www.oracle.com/cloud/costestimator.html)
- [OCI Support](https://www.oracle.com/cloud/support/)

## ✅ Summary

**This setup is 100% Always-Free:**
- ✅ Uses only VM.Standard.A1.Flex (Always-Free shape)
- ✅ Stays within 4 OCPU limit
- ✅ Stays within 24 GB memory limit
- ✅ Uses 3 of 4 available VM instances
- ✅ Stays within 200GB boot volume limit
- ✅ No paid services are created
- ✅ Validated at deployment time
- ✅ Will NEVER incur charges

**Deploy with confidence!** 🚀
