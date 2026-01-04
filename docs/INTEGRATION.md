# Integration with Existing Homelab

How to integrate this Oracle Cloud K3s cluster with your existing `seb-homelab-k8s-iac` infrastructure.

## 🎯 Goal

Deploy the same applications from your Proxmox homelab to this Oracle Cloud cluster.

## 📋 Prerequisites

1. Oracle Cloud K3s cluster deployed and accessible
2. Kubeconfig for Oracle cluster: `~/.kube/oracle-k3s-config`
3. Your existing `seb-homelab-k8s-iac` repo

## 🔄 Deployment Options

### Option 1: ArgoCD Multi-Cluster (Recommended)

Deploy ArgoCD on Oracle Cloud and manage applications there.

```bash
# Switch to Oracle Cloud context
export KUBECONFIG=~/.kube/oracle-k3s-config

# Deploy ArgoCD from your k8s-iac repo
cd /Users/seb/repos/seb-homelab-k8s-iac/applications/argocd

# Apply ArgoCD (adjust for your setup)
kubectl apply -f manifests/

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then deploy your applications:

```bash
# Deploy app-of-apps
kubectl apply -f applications/app_of_apps/
```

### Option 2: Direct kubectl Apply

Deploy applications directly using kubectl.

```bash
export KUBECONFIG=~/.kube/oracle-k3s-config

# Example: Deploy from KCL-generated manifests
cd /Users/seb/repos/seb-homelab-k8s-iac/applications/tandoor_kcl
make manifests
kubectl apply -f manifests/
```

### Option 3: GitLab CI/CD Multi-Environment

Use your existing GitLab CI/CD with multiple environments.

```yaml
# .gitlab-ci.yml addition
deploy:oracle:
  stage: deploy
  script:
    - export KUBECONFIG=${ORACLE_KUBECONFIG}
    - kubectl apply -f manifests/
  environment:
    name: oracle-cloud
  only:
    - main
```

## 🔧 Modifications Needed

### 1. Storage Classes

Oracle Cloud doesn't have Longhorn by default. Options:

#### A. Install Longhorn

```bash
# Same as Proxmox setup
kubectl apply -f /Users/seb/repos/seb-homelab-proxmox/proxmox/k3s-cluster/longhorn/values.yaml
```

#### B. Use OCI Block Volumes

Install OCI CSI driver:

```bash
# Deploy OCI CSI driver
kubectl apply -f https://raw.githubusercontent.com/oracle/oci-cloud-controller-manager/master/manifests/provider-config-instance-principals.yaml
```

Then update PVCs to use `oci-bv` storage class.

#### C. Use Local Storage

For non-critical data:

```bash
# Use K3s default local-path storage class
storageClassName: local-path
```

### 2. Ingress/Gateway API

Your homelab uses Gateway API. Options:

#### A. Install Gateway API Controllers

```bash
# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Deploy your global gateway
cd /Users/seb/repos/seb-homelab-k8s-iac/applications/global_gateway
make manifests
kubectl apply -f manifests/
```

#### B. Use NodePort

Temporarily expose services via NodePort:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: NodePort
  ports:
    - port: 80
      nodePort: 30080  # Access via <public-ip>:30080
```

#### C. Setup OCI Load Balancer

Install OCI Cloud Controller Manager for automatic LoadBalancer provisioning.

### 3. OAuth2 Proxy

Your Proxmox setup uses oauth2-proxy for authentication.

For Oracle Cloud:

```bash
# Deploy oauth2-proxy (adjust domain/secrets)
cd /Users/seb/repos/seb-homelab-k8s-iac/applications/oauth2_proxy_tandoor
make manifests
kubectl apply -f manifests/

# Update redirect URIs in Auth0/your OAuth provider
# Add: https://<oracle-public-ip>/oauth2/callback
```

### 4. Sealed Secrets

If using Sealed Secrets:

```bash
# Deploy sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Seal secrets for Oracle cluster
kubeseal --cert <oracle-cert.pem> < secret.yaml > sealed-secret.yaml
```

### 5. DNS Configuration

Options for DNS:

#### A. Cloudflare DNS (Recommended)

Update Cloudflare DNS to point to Oracle public IPs:

```bash
# Get public IPs
make status

# Update DNS records
A     app.yourdomain.com  -> <oracle-worker-1-public-ip>
A     api.yourdomain.com  -> <oracle-control-1-public-ip>
```

#### B. External DNS

Deploy external-dns to auto-update DNS:

```bash
# Install external-dns with Cloudflare provider
# Configure with your Cloudflare API token
```

#### C. Use Public IPs directly

For testing, use public IPs:

```
http://<public-ip>:30080
```

## 📦 Example: Deploying Tandoor to Oracle Cloud

```bash
# 1. Switch context
export KUBECONFIG=~/.kube/oracle-k3s-config

# 2. Create namespace
kubectl create namespace tandoor

# 3. Install Longhorn (for storage)
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml

# 4. Deploy postgres
cd /Users/seb/repos/seb-homelab-k8s-iac/applications/postgres_clusters
make manifests
kubectl apply -f manifests/

# 5. Deploy tandoor
cd /Users/seb/repos/seb-homelab-k8s-iac/applications/tandoor_kcl
make manifests
kubectl apply -f manifests/

# 6. Expose via NodePort (temporary)
kubectl patch service tandoor -n tandoor -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30080}]}}'

# 7. Access at http://<worker-public-ip>:30080
```

## 🔐 Secrets Management

### Option 1: Sealed Secrets (Current Setup)

Generate new sealed secrets for Oracle cluster:

```bash
# Get sealing certificate from Oracle cluster
kubeseal --fetch-cert --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system > oracle-cert.pem

# Seal your secrets
kubeseal --cert oracle-cert.pem < secret.yaml > sealed-secret.yaml
kubectl apply -f sealed-secret.yaml
```

### Option 2: External Secrets Operator

Use AWS Secrets Manager or another secret backend:

```bash
# Install External Secrets Operator
kubectl apply -f https://github.com/external-secrets/external-secrets/releases/latest/download/install.yaml

# Configure with AWS Secrets Manager / Vault / etc.
```

### Option 3: Manual Secrets

For testing, manually create secrets:

```bash
kubectl create secret generic my-secret \
  --from-literal=password='...' \
  --from-literal=api-key='...'
```

## 🌐 Networking Comparison

| Feature | Proxmox Homelab | Oracle Cloud |
|---------|-----------------|--------------|
| CNI | Flannel/Calico | Flannel (K3s default) |
| LoadBalancer | MetalLB | NodePort or OCI LB |
| Ingress | Gateway API | Gateway API or nginx |
| Private IPs | 172.16.16.0/24 | 10.0.1.0/24 |
| Public Access | Via home IP + NAT | Direct public IPs |
| Network Policies | Yes | Can add Calico |

## 📊 Resource Considerations

| Resource | Proxmox | Oracle Cloud | Notes |
|----------|---------|--------------|-------|
| Control Planes | 3x (4 vCPU, 12GB) | 1x (2 OCPU, 12GB) | Oracle: Single point of failure |
| Workers | 3x | 2x (1 OCPU, 6GB) | Oracle: Less capacity |
| Storage | Longhorn on local disks | Need to install Longhorn or use OCI | |
| Total CPU | ~12 cores | 4 OCPUs (ARM) | ARM is very efficient |
| Total RAM | ~36GB | 24GB | Need to be more selective |

### Recommendations for Oracle Cloud

1. **Deploy fewer applications** - pick your favorites
2. **Use smaller resource limits** - ARM is efficient
3. **Skip heavy workloads** - Elasticsearch, etc.
4. **Focus on stateless apps** - or use OCI block volumes

### Good Candidates for Oracle Cloud

✅ **Yes - Light weight:**
- ArgoCD
- Simple web apps
- API services
- Tandoor (with postgres)
- OAuth2 Proxy
- Sealed Secrets

⚠️ **Maybe - Medium weight:**
- Prometheus (small retention)
- Grafana
- Postgres (small databases)
- Vault (small workloads)

❌ **No - Too heavy:**
- Elasticsearch (huge memory usage)
- Huly (too many services)
- Large databases
- Resource-intensive builds

## 🚀 Quick Migration Checklist

- [ ] Oracle Cloud K3s cluster deployed
- [ ] Kubeconfig accessible
- [ ] Storage solution chosen (Longhorn/OCI/local)
- [ ] Ingress solution chosen (Gateway API/nginx)
- [ ] DNS configured
- [ ] Secrets sealed/migrated
- [ ] ArgoCD deployed
- [ ] Test application deployed
- [ ] Monitoring deployed (Prometheus/Grafana)
- [ ] Backups configured

## 🔄 Keeping Both Clusters in Sync

### Option A: Shared GitOps Repo (Recommended)

```bash
# Use same repo, different branches
git checkout oracle-cloud
# Make oracle-specific changes
git push
```

ArgoCD on Oracle tracks `oracle-cloud` branch.

### Option B: Multi-Cluster ArgoCD

Run ArgoCD on Proxmox, manage both clusters:

```bash
# Add Oracle cluster to ArgoCD
argocd cluster add oracle-k3s --name oracle-cloud
```

### Option C: Separate Repos

Fork or copy your k8s-iac repo:

```bash
# Clone to oracle-specific repo
cp -r seb-homelab-k8s-iac seb-homelab-k8s-iac-oracle
cd seb-homelab-k8s-iac-oracle
# Make oracle-specific changes
```

## 📚 Next Steps

1. **Choose your deployment option** (ArgoCD recommended)
2. **Install storage** (Longhorn recommended)
3. **Setup ingress** (Gateway API if possible)
4. **Migrate secrets** (Sealed Secrets)
5. **Deploy ArgoCD** (for GitOps)
6. **Deploy applications** (start with simple ones)
7. **Configure monitoring** (Prometheus/Grafana)
8. **Setup backups** (to OCI Object Storage - 10GB free)

## 💡 Pro Tips

- **Start small**: Deploy 1-2 apps first, verify everything works
- **Monitor resources**: ARM is efficient but you have limited capacity
- **Use resource quotas**: Prevent resource exhaustion
- **Setup alerts**: Monitor cluster health
- **Document differences**: Note what's different from Proxmox setup
- **Test failover**: Practice switching between clusters

Enjoy running your homelab in the cloud! ☁️

