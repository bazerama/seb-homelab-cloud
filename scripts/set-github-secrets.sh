#!/usr/bin/env bash

# Script to automatically set all GitHub secrets using gh CLI
# Usage: ./set-github-secrets.sh [--list-only|--help]

set -euo pipefail

# Show help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Automatically set GitHub repository secrets from terraform.tfvars"
    echo ""
    echo "Options:"
    echo "  --list-only    Check which secrets exist without modifying them"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Set all secrets (prompts before overwriting)"
    echo "  $0 --list-only       # Check status of secrets"
    echo ""
    exit 0
fi

# Check for --list-only flag
LIST_ONLY=false
if [ "${1:-}" = "--list-only" ]; then
    LIST_ONLY=true
fi

echo "🔐 Automated GitHub Secrets Setup"
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ gh CLI not found${NC}"
    echo "Install it with: brew install gh"
    echo "Or visit: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not authenticated with GitHub${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ gh CLI is installed and authenticated${NC}"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars not found${NC}"
    echo "Please run this script from the repository root"
    exit 1
fi

echo "📋 Reading values from terraform.tfvars..."
echo ""

# Function to extract value from terraform.tfvars
get_tfvar() {
    local key=$1
    grep "^${key}" terraform.tfvars | cut -d'=' -f2 | tr -d ' "' || echo ""
}

# Function to check if a secret exists
secret_exists() {
    local name=$1
    gh secret list | grep -q "^${name}"
}

# Function to set a secret
set_secret() {
    local name=$1
    local value=$2

    if [ -z "$value" ]; then
        echo -e "${YELLOW}⚠️  Skipping ${name} (empty value)${NC}"
        return
    fi

    if secret_exists "$name"; then
        echo -n "Updating ${name}... "
    else
        echo -n "Setting ${name}... "
    fi

    if echo "$value" | gh secret set "$name"; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
}

# Extract values
TENANCY_OCID=$(get_tfvar "tenancy_ocid")
USER_OCID=$(get_tfvar "user_ocid")
FINGERPRINT=$(get_tfvar "fingerprint")
COMPARTMENT_OCID=$(get_tfvar "compartment_ocid")
REGION=$(get_tfvar "region")
AVAILABILITY_DOMAIN=$(get_tfvar "availability_domain")
ARM_IMAGE_OCID=$(get_tfvar "arm_image_ocid")

# Get private key path and read the key
PRIVATE_KEY_PATH=$(get_tfvar "private_key_path")
if [ -n "$PRIVATE_KEY_PATH" ]; then
    # Expand ~ to home directory
    PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH/#\~/$HOME}"

    if [ -f "$PRIVATE_KEY_PATH" ]; then
        PRIVATE_KEY=$(cat "$PRIVATE_KEY_PATH")
    else
        echo -e "${YELLOW}⚠️  Private key file not found: ${PRIVATE_KEY_PATH}${NC}"
        PRIVATE_KEY=""
    fi
else
    PRIVATE_KEY=""
fi

# Get SSH public key
SSH_KEY_PATH=$(get_tfvar "ssh_public_key_path")
if [ -n "$SSH_KEY_PATH" ]; then
    # Expand ~ to home directory
    SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

    if [ -f "$SSH_KEY_PATH" ]; then
        SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")
    else
        echo -e "${YELLOW}⚠️  SSH public key file not found: ${SSH_KEY_PATH}${NC}"
        SSH_PUBLIC_KEY=""
    fi
else
    SSH_PUBLIC_KEY=""
fi

echo "🔍 Checking existing secrets..."
echo ""

# List of secrets we're going to set
SECRETS_TO_SET=(
    "OCI_TENANCY_OCID"
    "OCI_USER_OCID"
    "OCI_FINGERPRINT"
    "OCI_COMPARTMENT_OCID"
    "OCI_REGION"
    "OCI_AVAILABILITY_DOMAIN"
    "OCI_ARM_IMAGE_OCID"
    "OCI_PRIVATE_KEY"
    "SSH_PUBLIC_KEY"
)

# Check which secrets already exist
EXISTING_SECRETS=()
MISSING_SECRETS=()
for secret in "${SECRETS_TO_SET[@]}"; do
    if secret_exists "$secret"; then
        EXISTING_SECRETS+=("$secret")
    else
        MISSING_SECRETS+=("$secret")
    fi
done

# If --list-only, just show status and exit
if [ "$LIST_ONLY" = true ]; then
    echo "📋 Secret Status:"
    echo ""
    if [ ${#EXISTING_SECRETS[@]} -gt 0 ]; then
        echo -e "${GREEN}✅ Already Set (${#EXISTING_SECRETS[@]}):${NC}"
        for secret in "${EXISTING_SECRETS[@]}"; do
            echo "   • $secret"
        done
        echo ""
    fi
    if [ ${#MISSING_SECRETS[@]} -gt 0 ]; then
        echo -e "${YELLOW}❌ Not Set (${#MISSING_SECRETS[@]}):${NC}"
        for secret in "${MISSING_SECRETS[@]}"; do
            echo "   • $secret"
        done
        echo ""
    fi
    if [ ${#MISSING_SECRETS[@]} -eq 0 ]; then
        echo -e "${GREEN}All secrets are already configured! ✅${NC}"
    else
        echo "Run without --list-only to set missing secrets"
    fi
    exit 0
fi

# Warn if secrets exist
if [ ${#EXISTING_SECRETS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: The following secrets already exist and will be OVERWRITTEN:${NC}"
    for secret in "${EXISTING_SECRETS[@]}"; do
        echo "   • $secret"
    done
    echo ""
    if [ ${#MISSING_SECRETS[@]} -gt 0 ]; then
        echo -e "${GREEN}The following secrets will be CREATED:${NC}"
        for secret in "${MISSING_SECRETS[@]}"; do
            echo "   • $secret"
        done
        echo ""
    fi
    read -p "Continue and overwrite existing secrets? (yes/no): " -r CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]es$ ]]; then
        echo -e "${YELLOW}❌ Aborted by user${NC}"
        exit 0
    fi
    echo ""
else
    echo -e "${GREEN}✅ No existing secrets found - will create new ones${NC}"
    echo ""
fi

echo "🚀 Setting GitHub Secrets..."
echo ""

# Set all secrets
set_secret "OCI_TENANCY_OCID" "$TENANCY_OCID"
set_secret "OCI_USER_OCID" "$USER_OCID"
set_secret "OCI_FINGERPRINT" "$FINGERPRINT"
set_secret "OCI_COMPARTMENT_OCID" "$COMPARTMENT_OCID"
set_secret "OCI_REGION" "$REGION"
set_secret "OCI_AVAILABILITY_DOMAIN" "$AVAILABILITY_DOMAIN"
set_secret "OCI_ARM_IMAGE_OCID" "$ARM_IMAGE_OCID"
set_secret "OCI_PRIVATE_KEY" "$PRIVATE_KEY"
set_secret "SSH_PUBLIC_KEY" "$SSH_PUBLIC_KEY"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ GitHub Secrets Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
if [ ${#EXISTING_SECRETS[@]} -gt 0 ]; then
    echo "   Updated: ${#EXISTING_SECRETS[@]} secret(s)"
    echo "   Created: $((${#SECRETS_TO_SET[@]} - ${#EXISTING_SECRETS[@]})) secret(s)"
else
    echo "   Created: ${#SECRETS_TO_SET[@]} secret(s)"
fi
echo ""
echo "Verify secrets at:"
echo "https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/settings/secrets/actions"
echo ""
echo "💡 Tip: Run './scripts/set-github-secrets.sh --list-only' to check secret status"
echo ""
echo "Next steps:"
echo "1. Create or review your Pull Request"
echo "2. GitHub Actions will automatically run"
echo "3. After merge, manually trigger deployments from Actions tab"
echo ""
