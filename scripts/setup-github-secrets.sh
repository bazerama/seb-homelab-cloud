#!/usr/bin/env bash

# Script to help set up GitHub Secrets for OpenTofu workflow
# Usage: ./setup-github-secrets.sh

set -euo pipefail

echo "🔐 GitHub Secrets Setup Helper"
echo "==============================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}This script will show you the values to copy to GitHub Secrets.${NC}"
echo "It will NOT upload them automatically (for security)."
echo ""
read -p "Continue? (yes/no): " -r REPLY
echo ""
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    exit 0
fi

TFVARS="terraform.tfvars"

if [ ! -f "$TFVARS" ]; then
    echo "❌ terraform.tfvars not found!"
    echo "Please run this script from the repository root."
    exit 1
fi

echo "📋 GitHub Secrets Values"
echo "========================"
echo ""
echo "Go to: https://github.com/bazerama/seb-homelab-cloud/settings/secrets/actions"
echo "Click: New repository secret"
echo ""
echo "Copy these values (one at a time):"
echo ""

# Extract values from terraform.tfvars
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: OCI_TENANCY_OCID"
echo "Value:"
grep "^tenancy_ocid" "$TFVARS" | cut -d'=' -f2 | tr -d ' "'
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: OCI_USER_OCID"
echo "Value:"
grep "^user_ocid" "$TFVARS" | cut -d'=' -f2 | tr -d ' "'
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: OCI_FINGERPRINT"
echo "Value:"
grep "^fingerprint" "$TFVARS" | cut -d'=' -f2 | tr -d ' "'
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: OCI_COMPARTMENT_OCID"
echo "Value:"
grep "^compartment_ocid" "$TFVARS" | cut -d'=' -f2 | tr -d ' "'
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: OCI_REGION"
echo "Value:"
grep "^region" "$TFVARS" | cut -d'=' -f2 | tr -d ' "'
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: OCI_AVAILABILITY_DOMAIN"
echo "Value:"
grep "^availability_domain" "$TFVARS" | cut -d'=' -f2 | tr -d ' "'
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: OCI_ARM_IMAGE_OCID"
echo "Value:"
grep "^arm_image_ocid" "$TFVARS" | cut -d'=' -f2 | tr -d ' "'
echo ""

# Private key
PRIVATE_KEY_PATH=$(grep "^private_key_path" "$TFVARS" | cut -d'=' -f2 | tr -d ' "' | sed "s|~|$HOME|")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: OCI_PRIVATE_KEY"
echo -e "${YELLOW}⚠️  SENSITIVE - Keep this private!${NC}"
echo "Value (include BEGIN and END lines):"
echo ""
if [ -f "$PRIVATE_KEY_PATH" ]; then
    cat "$PRIVATE_KEY_PATH"
else
    echo "❌ Private key not found at: $PRIVATE_KEY_PATH"
fi
echo ""

# SSH public key
SSH_KEY_PATH=$(grep "^ssh_public_key_path" "$TFVARS" | cut -d'=' -f2 | tr -d ' "' | sed "s|~|$HOME|")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret Name: SSH_PUBLIC_KEY"
echo "Value:"
if [ -f "$SSH_KEY_PATH" ]; then
    cat "$SSH_KEY_PATH"
else
    echo "❌ SSH public key not found at: $SSH_KEY_PATH"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✅ All values displayed above${NC}"
echo ""
echo "Next steps:"
echo "1. Go to: https://github.com/bazerama/seb-homelab-cloud/settings/secrets/actions"
echo "2. For each secret above:"
echo "   - Click 'New repository secret'"
echo "   - Copy the Secret Name"
echo "   - Copy the Value"
echo "   - Click 'Add secret'"
echo ""
echo "3. Set up 'production' environment:"
echo "   - Go to: Settings → Environments"
echo "   - Click 'New environment'"
echo "   - Name: production"
echo "   - Add protection rules:"
echo "     ✓ Required reviewers (add yourself)"
echo "   - Save"
echo ""
echo "4. Test the workflow:"
echo "   - Go to Actions tab"
echo "   - Run 'OpenTofu CI/CD' workflow manually"
echo "   - Select 'plan' action"
echo ""
