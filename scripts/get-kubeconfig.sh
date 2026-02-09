#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
MERGE_CONFIG=false
CONTEXT_NAME="oci-k3s"

while [[ $# -gt 0 ]]; do
    case $1 in
        --merge)
            MERGE_CONFIG=true
            shift
            ;;
        --context-name)
            CONTEXT_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --merge              Merge with existing ~/.kube/config instead of creating separate file"
            echo "  --context-name NAME  Set custom context name (default: oci-k3s)"
            echo "  --help               Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  KUBECONFIG_PATH      Path to save kubeconfig (default: ~/.kube/oci-k3s-config)"
            echo "  SSH_KEY              Path to SSH private key (default: ~/.ssh/oracle_vm_ssh_key)"
            echo "  SSH_USER             SSH user (default: opc)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Configuration
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube/oci-k3s-config}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/oracle_vm_ssh_key}"
SSH_USER="${SSH_USER:-opc}"
DEFAULT_KUBECONFIG="$HOME/.kube/config"

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

# Update cluster/context names
sed -i.bak2 "s|name: default|name: $CONTEXT_NAME|g" "$TEMP_CONFIG"
sed -i.bak3 "s|cluster: default|cluster: $CONTEXT_NAME|g" "$TEMP_CONFIG"
sed -i.bak4 "s|user: default|user: $CONTEXT_NAME|g" "$TEMP_CONFIG"

# Create .kube directory if it doesn't exist
mkdir -p "$(dirname "$KUBECONFIG_PATH")"
mkdir -p "$HOME/.kube"

if [ "$MERGE_CONFIG" = true ]; then
    echo "🔀 Merging with existing kubeconfig..."

    # Save temp config to a file
    TEMP_NEW_CONFIG=$(mktemp)
    cp "$TEMP_CONFIG" "$TEMP_NEW_CONFIG"

    if [ -f "$DEFAULT_KUBECONFIG" ]; then
        # Backup existing config
        cp "$DEFAULT_KUBECONFIG" "$DEFAULT_KUBECONFIG.backup.$(date +%Y%m%d-%H%M%S)"
        echo -e "${GREEN}✓${NC} Backed up existing config"

        # Remove existing entries for this context (so we get a clean overwrite)
        kubectl config delete-context "$CONTEXT_NAME" &>/dev/null || true
        kubectl config delete-cluster "$CONTEXT_NAME" &>/dev/null || true
        kubectl config delete-user "$CONTEXT_NAME" &>/dev/null || true

        # Merge configs using kubectl
        KUBECONFIG="$DEFAULT_KUBECONFIG:$TEMP_NEW_CONFIG" kubectl config view --flatten > "$DEFAULT_KUBECONFIG.tmp"
        mv "$DEFAULT_KUBECONFIG.tmp" "$DEFAULT_KUBECONFIG"
        chmod 600 "$DEFAULT_KUBECONFIG"

        # Set the new context as current
        kubectl config use-context "$CONTEXT_NAME" &>/dev/null || true

        echo -e "${GREEN}✓${NC} Merged with $DEFAULT_KUBECONFIG"
        echo -e "${GREEN}✓${NC} Set context to: $CONTEXT_NAME"

        # Also save standalone copy
        cp "$TEMP_NEW_CONFIG" "$KUBECONFIG_PATH"
        chmod 600 "$KUBECONFIG_PATH"
        echo -e "${BLUE}ℹ${NC}  Standalone copy saved to: $KUBECONFIG_PATH"
    else
        # No existing config, just save the new one
        cp "$TEMP_NEW_CONFIG" "$DEFAULT_KUBECONFIG"
        chmod 600 "$DEFAULT_KUBECONFIG"
        echo -e "${GREEN}✓${NC} Saved to $DEFAULT_KUBECONFIG"
    fi

    rm -f "$TEMP_NEW_CONFIG"
else
    # Save kubeconfig to separate file
    cp "$TEMP_CONFIG" "$KUBECONFIG_PATH"
    chmod 600 "$KUBECONFIG_PATH"
    echo -e "${GREEN}✓${NC} Kubeconfig saved to: $KUBECONFIG_PATH"
fi

rm -f "$TEMP_CONFIG" "$TEMP_CONFIG.bak" "$TEMP_CONFIG.bak2" "$TEMP_CONFIG.bak3" "$TEMP_CONFIG.bak4"
echo ""

# Test connection
echo "🧪 Testing connection..."
if [ "$MERGE_CONFIG" = true ]; then
    # Test with merged config
    if kubectl cluster-info --context="$CONTEXT_NAME" &>/dev/null; then
        echo -e "${GREEN}✓${NC} Successfully connected to cluster!"
        echo ""

        # Show cluster info
        echo "📊 Cluster Information:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        kubectl cluster-info --context="$CONTEXT_NAME"
        echo ""
        kubectl get nodes --context="$CONTEXT_NAME"
    else
        echo -e "${YELLOW}⚠️  Warning: Could not connect to cluster${NC}"
        echo "   The kubeconfig has been merged, but the cluster may not be fully ready yet"
        echo "   Try again in a few minutes with: kubectl --context=$CONTEXT_NAME get nodes"
    fi
else
    # Test with standalone config
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
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$MERGE_CONFIG" = true ]; then
    echo "📋 Usage (merged into default kubeconfig):"
    echo "   kubectl get nodes --context=$CONTEXT_NAME"
    echo "   kubectl get pods -A --context=$CONTEXT_NAME"
    echo ""
    echo "💡 Switch to this cluster:"
    echo "   kubectl config use-context $CONTEXT_NAME"
    echo ""
    echo "📂 View all contexts:"
    echo "   kubectl config get-contexts"
    echo ""
    echo "💾 Standalone copy also available at:"
    echo "   $KUBECONFIG_PATH"
else
    echo "📋 Usage (standalone kubeconfig):"
    echo "   export KUBECONFIG=$KUBECONFIG_PATH"
    echo "   kubectl get nodes"
    echo ""
    echo "💡 Or use with --kubeconfig flag:"
    echo "   kubectl --kubeconfig=$KUBECONFIG_PATH get pods -A"
    echo ""
    echo "🔀 To merge with default kubeconfig:"
    echo "   $0 --merge"
fi
echo ""
