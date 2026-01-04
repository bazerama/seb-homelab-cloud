# Cloud Provider Cost Comparison for K3s

Detailed cost analysis for running a K3s cluster on various cloud providers.

## 💰 Monthly Cost Comparison (3-Node Cluster)

| Provider | Config | Monthly Cost | Annual Cost | Notes |
|----------|--------|--------------|-------------|-------|
| **Oracle Cloud** | 1x (2 OCPU, 12GB) + 2x (1 OCPU, 6GB) ARM | **$0** | **$0** | Free tier forever! |
| **Hetzner** | 3x CPX11 (2 vCPU, 2GB) | $13 | $156 | Best paid option |
| **DigitalOcean** | 3x Droplet (2 vCPU, 2GB) | $36 | $432 | Simple, reliable |
| **Linode** | 3x Shared (2 vCPU, 4GB) | $36 | $432 | Similar to DO |
| **AWS EC2** | 3x t4g.small (2 vCPU, 2GB) ARM | $38 | $456 | With 1yr reserved |
| **AWS EC2** | 3x t3a.small (2 vCPU, 2GB) x86 | $46 | $552 | On-demand pricing |
| **GCP** | 3x e2-small (2 vCPU, 2GB) | $49 | $588 | Sustained use discount |
| **Azure** | 3x B2s (2 vCPU, 4GB) | $60 | $720 | More expensive |
| **AWS EKS** | Managed control plane + 2 workers | $145 | $1,740 | Don't do this! |

## 📊 Detailed Breakdown

### Oracle Cloud Ampere Always-Free Tier (🏆 Winner)

**What you get (per tenancy, forever):**
- 4 ARM OCPUs (Ampere A1 - ARM64)
- 24GB RAM total
- 200GB block storage
- 10TB monthly egress
- 1 flexible load balancer (10 Mbps)
- 2 public IPv4 addresses (reserved)
- Unlimited ephemeral public IPs
- Up to 4 VM instances (practically)
- 2 x86 VMs (1/8 OCPU, 1GB each) - too weak for K8s
- **Forever free** - No 12-month trial, actually permanent!

**Our configuration:**
```
Control Plane: 2 OCPU, 12GB RAM, 50GB storage
Worker 1:      1 OCPU,  6GB RAM, 50GB storage
Worker 2:      1 OCPU,  6GB RAM, 50GB storage
-------------------------------------------------
Total:         4 OCPU, 24GB RAM, 150GB storage
Cost:          $0/month
```

**Pros:**
- ✅ Completely free
- ✅ ARM CPUs are fast and efficient
- ✅ Generous resources for free tier
- ✅ No time limit (unlike AWS/GCP 12-month trials)
- ✅ Production-grade infrastructure

**Cons:**
- ❌ ARM capacity is limited (high demand)
- ❌ UI is clunky compared to AWS/GCP
- ❌ Smaller ecosystem/community
- ❌ Must be "active" (login once every 30 days)

**Best for:** Homelab, learning, testing, small production workloads

---

### Hetzner Cloud (🥈 Best Paid Option)

**Configuration:**
```
3x CPX11
- 2 AMD vCPU
- 2GB RAM
- 40GB NVMe SSD
- 20TB traffic

€4.15/month each = €12.45/month ($13/month)
```

**Pros:**
- ✅ Extremely cheap
- ✅ Great performance
- ✅ Excellent network (20TB free traffic!)
- ✅ Simple API
- ✅ Fast NVMe storage
- ✅ Good uptime

**Cons:**
- ❌ EU only (Germany, Finland)
- ❌ Smaller ecosystem than AWS/GCP
- ❌ No managed Kubernetes (DIY K3s only)

**Best for:** European users, cost-conscious deployments, production on a budget

---

### DigitalOcean

**Configuration:**
```
3x Regular Droplets
- 2 vCPU (Intel)
- 2GB RAM
- 50GB SSD
- 3TB transfer

$12/month each = $36/month
```

Or use DOKS (managed Kubernetes):
- Control plane: Free
- Workers: Same pricing
- Total: $36/month

**Pros:**
- ✅ Simple, clean UI
- ✅ Good documentation
- ✅ Managed K8s option (free control plane)
- ✅ Global presence
- ✅ Reliable

**Cons:**
- ❌ More expensive than Hetzner
- ❌ Fewer services than AWS/GCP
- ❌ No free tier

**Best for:** Those who value simplicity, managed K8s, good support

---

### AWS EC2 (DIY K3s)

**Configuration (ARM):**
```
3x t4g.small (1-year reserved)
- 2 vCPU (ARM Graviton2)
- 2GB RAM
- 30GB EBS gp3

$0.0105/hr each (reserved) = $38/month
Or $0.0168/hr (on-demand) = $61/month
```

**With Spot Instances:**
- 70% discount vs on-demand
- Can go as low as $18/month
- Risk of interruption

**Pros:**
- ✅ Huge ecosystem
- ✅ Integrates with all AWS services
- ✅ ARM instances are fast
- ✅ Spot instances very cheap
- ✅ Global coverage

**Cons:**
- ❌ Complex pricing
- ❌ Complex to setup
- ❌ Free tier only 12 months
- ❌ More expensive than alternatives
- ❌ Data transfer costs

**Best for:** Already on AWS, need AWS integration, using spot instances

---

### AWS EKS (Managed)

**Configuration:**
```
Control Plane: $0.10/hour = $72/month
3x t4g.small workers = $38/month
-----------------------------------------
Total: $110/month minimum
```

**Pros:**
- ✅ Fully managed control plane
- ✅ Highly available
- ✅ Integrates with AWS services
- ✅ Auto-updates

**Cons:**
- ❌ Expensive! $72/month just for control plane
- ❌ Same worker costs as DIY
- ❌ Overkill for homelab
- ❌ Complex to configure

**Best for:** Production enterprise workloads, NOT homelab

---

### Google Cloud Platform (GCP)

**Configuration:**
```
3x e2-small
- 2 vCPU
- 2GB RAM
- 10GB storage

$0.0669/hr with sustained use = $49/month
```

Or GKE (managed):
- Control plane: $0.10/hr = $72/month
- Workers: Same as above
- Total: $121/month

**Pros:**
- ✅ Good UI
- ✅ Fast network
- ✅ Sustained use discounts
- ✅ Free $300 credit (first 90 days)

**Cons:**
- ❌ More expensive than Hetzner/Oracle
- ❌ Complex pricing
- ❌ GKE is expensive

**Best for:** Using GCP services, want Google ecosystem

---

### Microsoft Azure

**Configuration:**
```
3x B2s
- 2 vCPU
- 4GB RAM
- Premium SSD

$0.0832/hr = $60/month
```

Or AKS (managed):
- Control plane: Free (basic tier)
- Workers: Same as above
- Total: $60/month

**Pros:**
- ✅ AKS control plane is free
- ✅ Good for enterprise
- ✅ Microsoft ecosystem

**Cons:**
- ❌ Most expensive option
- ❌ Complex
- ❌ Lower performance per dollar

**Best for:** Enterprise using Microsoft services

## 🎯 Recommendations by Use Case

### For Homelab / Learning
**🏆 Oracle Cloud Free Tier**
- Cost: $0/month
- Why: Can't beat free, good resources

### For Production on Budget
**🥈 Hetzner Cloud**
- Cost: $13/month
- Why: Best performance per dollar, reliable

### For Simplicity
**🥉 DigitalOcean DOKS**
- Cost: $36/month
- Why: Managed K8s, easy to use, good support

### For AWS Integration
**AWS EC2 + Spot Instances**
- Cost: $18-25/month
- Why: Cheap with spot, integrates with AWS services

### For Enterprise Production
**AWS EKS / GKE / AKS**
- Cost: $110-150/month
- Why: Fully managed, HA, enterprise support

## 💡 Cost Optimization Tips

### Oracle Cloud
- Use all 4 OCPUs available
- Use 200GB block storage efficiently
- Setup OCI budgets (free, alerts you)
- Use OCI monitoring (free)

### Any Provider
- Use spot/preemptible instances (save 70%)
- Right-size your instances (monitor resource usage)
- Use ARM instances where available (cheaper + faster)
- Setup auto-shutdown for dev/test (save ~70%)
- Use object storage for backups (very cheap)

### AWS Specific
- Buy reserved instances (1-3 year, save 40-60%)
- Use Savings Plans
- Use Spot instances for workers
- Enable Cost Explorer
- Use AWS Free Tier fully (12 months)

## 📈 Scaling Costs

If you need to grow beyond 3 nodes:

| Provider | 5-Node Cluster | 10-Node Cluster |
|----------|----------------|-----------------|
| Oracle | $0 (max 4 OCPUs)* | N/A (free tier limit) |
| Hetzner | $22/month | $44/month |
| DigitalOcean | $60/month | $120/month |
| AWS EC2 | $63/month | $127/month |
| AWS EKS | $144/month | $230/month |

*Oracle free tier has fixed limits, would need paid tier to scale

## 🔍 Hidden Costs to Consider

### Bandwidth/Egress
- **Oracle**: 10TB/month free ✅
- **Hetzner**: 20TB/month free ✅
- **DigitalOcean**: 3TB-6TB free ⚠️
- **AWS**: $0.09/GB (very expensive!) ❌
- **GCP**: $0.12/GB (very expensive!) ❌
- **Azure**: $0.087/GB (expensive!) ❌

### Load Balancers
- **Oracle**: 1 flexible LB free ✅
- **Hetzner**: €5/month ($5.50)
- **DigitalOcean**: $12/month
- **AWS**: $16/month + data processing
- **GCP**: $18/month + data processing
- **Azure**: $20/month + data processing

### Block Storage
- **Oracle**: 200GB free ✅
- **Hetzner**: Included in instance
- **DigitalOcean**: $0.10/GB ($10/100GB)
- **AWS**: $0.08/GB ($8/100GB)
- **GCP**: $0.10/GB ($10/100GB)
- **Azure**: $0.12/GB ($12/100GB)

### Backups
- **Oracle**: 10GB object storage free ✅
- **Hetzner**: €0.011/GB ($1.20/100GB)
- **DigitalOcean**: $5/month for droplet snapshots
- **AWS**: S3 $0.023/GB ($2.30/100GB)
- **GCP**: Cloud Storage $0.020/GB
- **Azure**: Blob Storage $0.018/GB

## 🎉 Final Verdict

### For Your Homelab: **Oracle Cloud Free Tier** 🏆

**Why:**
1. **Free forever** - can't argue with $0/month
2. **ARM CPUs** - Ampere A1 is excellent for K8s
3. **Enough resources** - 4 OCPU + 24GB RAM
4. **Same as Proxmox** - can run similar workloads
5. **Learning** - great for testing before buying

**Only downside:** Limited capacity, may take time to provision instances

### If Oracle Capacity Not Available: **Hetzner** 🥈

**Why:**
1. **Cheapest paid option** - $13/month is nothing
2. **Great performance** - fast CPUs, NVMe storage
3. **Simple** - no complex billing
4. **Reliable** - good uptime

**Setup is identical** - same K3s setup works on both!

---

## 📚 Additional Resources

- [Oracle Cloud Free Tier Details](https://www.oracle.com/cloud/free/)
- [Hetzner Cloud Pricing](https://www.hetzner.com/cloud)
- [DigitalOcean Pricing](https://www.digitalocean.com/pricing)
- [AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/)
- [AWS EKS Pricing](https://aws.amazon.com/eks/pricing/)

**Last Updated:** January 2026

