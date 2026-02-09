#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube/oci-k3s-config}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/oracle_vm_ssh_key}"
SSH_USER="${SSH_USER:-ubuntu}"

echo -e "${BLUE}🔧 Fetching K3s Kubeconfig from OCI${NC}"
echo "========================================"
echo ""

# Check if tofu state exists
if ! tofu state list &>/dev/null; then
    echo -e "${RED}❌ Error: No OpenTofu state found${NC}"
    echo "   Run 'tofu apply' first to create the infrastructure"
    exit 1
fi

# Get control plane public IP from state
echo "📡 Getting control plane IP from OpenTofu state..."
CONTROL_PLANE_IP=$(tofu output -raw k3s_control_plane_public_ip 2>/dev/null || echo "")

if [ -z "$CONTROL_PLANE_IP" ]; then
    echo -e "${RED}❌ Error: Could not get control plane IP${NC}"
    echo "   Make sure the infrastructure is deployed and 'k3s_control_plane_public_ip' output exists"
    exit 1
fi

echo -e "${GREEN}✓${NC} Control plane IP: $CONTROL_PLANE_IP"
echo ""

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}❌ Error: SSH key not found at $SSH_KEY${NC}"
    echo "   Set SSH_KEY environment variable or ensure key exists"
    exit 1
fi

echo "🔑 Using SSH key: $SSH_KEY"
echo ""

# Wait for instance to be ready
echo "⏳ Checking if instance is ready..."
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" "${SSH_USER}@${CONTROL_PLANE_IP}" "echo ready" &>/dev/null; then
        echo -e "${GREEN}✓${NC} Instance is ready"
        break
    fi

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "${RED}❌ Error: Instance not responding after $MAX_ATTEMPTS attempts${NC}"
        exit 1
    fi

    echo "   Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting for instance..."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

echo ""

# Wait for K3s to be ready
echo "⏳ Waiting for K3s to be ready..."
MAX_ATTEMPTS=60
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" "${SSH_USER}@${CONTROL_PLANE_IP}" "sudo test -f /etc/rancher/k3s/k3s.yaml" &>/dev/null; then
        echo -e "${GREEN}✓${NC} K3s is ready"
        break
    fi

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "${RED}❌ Error: K3s not ready after $MAX_ATTEMPTS attempts${NC}"
        echo "   Check K3s installation logs on the instance:"
        echo "   ssh -i $SSH_KEY ${SSH_USER}@${CONTROL_PLANE_IP} 'sudo journalctl -u k3s'"
        exit 1
    fi

    echo "   Attempt $ATTEMPT/$MAX_ATTEMPTS - K3s still initializing..."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

echo ""

# Fetch kubeconfig
echo "📥 Fetching kubeconfig from control plane..."
TEMP_CONFIG=$(mktemp)

if ! ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "${SSH_USER}@${CONTROL_PLANE_IP}" "sudo cat /etc/rancher/k3s/k3s.yaml" > "$TEMP_CONFIG"; then
    echo -e "${RED}❌ Error: Failed to fetch kubeconfig${NC}"
    rm -f "$TEMP_CONFIG"
    exit 1
fi

echo -e "${GREEN}✓${NC} Kubeconfig fetched"
echo ""

# Replace localhost with public IP
echo "🔧 Updating server URL..."
sed -i.bak "s|server: https://127.0.0.1:6443|server: https://${CONTROL_PLANE_IP}:6443|g" "$TEMP_CONFIG"

# Create .kube directory if it doesn't exist
mkdir -p "$(dirname "$KUBECONFIG_PATH")"

# Save kubeconfig
cp "$TEMP_CONFIG" "$KUBECONFIG_PATH"
chmod 600 "$KUBECONFIG_PATH"
rm -f "$TEMP_CONFIG" "$TEMP_CONFIG.bak"

echo -e "${GREEN}✓${NC} Kubeconfig saved to: $KUBECONFIG_PATH"
echo ""

# Test connection
echo "🧪 Testing connection..."
if KUBECONFIG="$KUBECONFIG_PATH" kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓${NC} Successfully connected to cluster!"
    echo ""

    # Show cluster info
    echo "📊 Cluster Information:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    KUBECONFIG="$KUBECONFIG_PATH" kubectl cluster-info
    echo ""
    KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes
else
    echo -e "${YELLOW}⚠️  Warning: Could not connect to cluster${NC}"
    echo "   The kubeconfig has been saved, but the cluster may not be fully ready yet"
    echo "   Try again in a few minutes with: kubectl --kubeconfig=$KUBECONFIG_PATH get nodes"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Usage:"
echo "   export KUBECONFIG=$KUBECONFIG_PATH"
echo "   kubectl get nodes"
echo ""
echo "💡 Or use with --kubeconfig flag:"
echo "   kubectl --kubeconfig=$KUBECONFIG_PATH get pods -A"
echo ""
echo "🔗 To set as default kubeconfig:"
echo "   cp $KUBECONFIG_PATH ~/.kube/config"
echo ""
