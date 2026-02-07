#!/usr/bin/env bash

# Script to automatically update GitHub Secrets from terraform.tfvars
# Usage: ./scripts/update-github-secrets.sh [--list-only|--help]

set -euo pipefail

# Show help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Automatically update GitHub repository secrets from terraform.tfvars"
    echo ""
    echo "Options:"
    echo "  --list-only    Check which secrets exist without modifying them"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Update all secrets (prompts before overwriting)"
    echo "  $0 --list-only       # Check status of secrets"
    echo ""
    exit 0
fi

# Check for --list-only flag
LIST_ONLY=false
if [ "${1:-}" = "--list-only" ]; then
    LIST_ONLY=true
fi

echo "🔐 Update GitHub Secrets from terraform.tfvars"
echo "==============================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Install it: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not authenticated with GitHub CLI${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ gh CLI is authenticated${NC}"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars not found!${NC}"
    echo "Please run this script from the repository root."
    exit 1
fi

# Function to extract value from tfvars and clean it
get_tfvar() {
    local var_name=$1
    # Extract value, strip quotes, remove inline comments, and trim whitespace
    grep "^${var_name}" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d '"' | xargs
}

# Function to get file content
get_file_content() {
    local path=$1
    local expanded_path="${path/#\~/$HOME}"
    if [ -f "$expanded_path" ]; then
        cat "$expanded_path"
    else
        echo -e "${RED}ERROR: File not found at $expanded_path${NC}"
        exit 1
    fi
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

echo "📋 Reading values from terraform.tfvars..."
echo ""

# Extract all values
TENANCY_OCID=$(get_tfvar "tenancy_ocid")
USER_OCID=$(get_tfvar "user_ocid")
FINGERPRINT=$(get_tfvar "fingerprint")
COMPARTMENT_OCID=$(get_tfvar "compartment_ocid")
REGION=$(get_tfvar "region")
AVAILABILITY_DOMAIN=$(get_tfvar "availability_domain")
ARM_IMAGE_OCID=$(get_tfvar "arm_image_ocid")
BILLING_EMAIL=$(get_tfvar "billing_alert_email")

PRIVATE_KEY_PATH=$(get_tfvar "private_key_path")
SSH_PUBLIC_KEY_PATH=$(get_tfvar "ssh_public_key_path")

PRIVATE_KEY=$(get_file_content "$PRIVATE_KEY_PATH")
SSH_PUBLIC_KEY=$(get_file_content "$SSH_PUBLIC_KEY_PATH")

# Get remote state credentials from .envrc if it exists
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
TF_BACKEND_NAMESPACE=""

if [ -f ".envrc" ]; then
    echo "📦 Found .envrc - reading remote state credentials..."
    AWS_ACCESS_KEY_ID=$(grep "^export AWS_ACCESS_KEY_ID=" .envrc | cut -d'"' -f2)
    AWS_SECRET_ACCESS_KEY=$(grep "^export AWS_SECRET_ACCESS_KEY=" .envrc | cut -d'"' -f2)

    # Get namespace from OCI if not in .envrc
    if command -v oci &> /dev/null && [ -f ~/.oci/config ]; then
        TF_BACKEND_NAMESPACE=$(oci os ns get --query 'data' --raw-output 2>/dev/null || echo "")
    fi
    echo ""
fi

# Verify required values
if [ -z "$TENANCY_OCID" ] || [ -z "$REGION" ]; then
    echo -e "${RED}❌ Missing required values in terraform.tfvars${NC}"
    echo "Please ensure all variables are set correctly"
    exit 1
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
    "OCI_BILLING_ALERT_EMAIL"
    "OCI_PRIVATE_KEY"
    "SSH_PUBLIC_KEY"
)

# Add remote state secrets if available
if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    SECRETS_TO_SET+=("AWS_ACCESS_KEY_ID")
fi
if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    SECRETS_TO_SET+=("AWS_SECRET_ACCESS_KEY")
fi
if [ -n "$TF_BACKEND_NAMESPACE" ]; then
    SECRETS_TO_SET+=("TF_BACKEND_NAMESPACE")
fi

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

echo "📊 Values to be set:"
echo "  • Region: $REGION"
echo "  • Availability Domain: $AVAILABILITY_DOMAIN"
if [ -n "$BILLING_EMAIL" ]; then
    echo "  • Billing Email: $BILLING_EMAIL"
fi
echo "  • ARM Image OCID: ${ARM_IMAGE_OCID:0:40}..."
if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo "  • Remote State: Enabled (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, TF_BACKEND_NAMESPACE)"
fi
echo ""

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

echo "🚀 Updating GitHub Secrets..."
echo ""

# Set all secrets
set_secret "OCI_TENANCY_OCID" "$TENANCY_OCID"
set_secret "OCI_USER_OCID" "$USER_OCID"
set_secret "OCI_FINGERPRINT" "$FINGERPRINT"
set_secret "OCI_COMPARTMENT_OCID" "$COMPARTMENT_OCID"
set_secret "OCI_REGION" "$REGION"
set_secret "OCI_AVAILABILITY_DOMAIN" "$AVAILABILITY_DOMAIN"
set_secret "OCI_ARM_IMAGE_OCID" "$ARM_IMAGE_OCID"
set_secret "OCI_BILLING_ALERT_EMAIL" "$BILLING_EMAIL"
set_secret "OCI_PRIVATE_KEY" "$PRIVATE_KEY"
set_secret "SSH_PUBLIC_KEY" "$SSH_PUBLIC_KEY"

# Set remote state secrets if available
if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    echo ""
    echo "🔐 Setting remote state secrets..."
    set_secret "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
    set_secret "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"
    set_secret "TF_BACKEND_NAMESPACE" "$TF_BACKEND_NAMESPACE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ GitHub Secrets Updated Successfully!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
if [ ${#EXISTING_SECRETS[@]} -gt 0 ]; then
    echo "   Updated: ${#EXISTING_SECRETS[@]} secret(s)"
    if [ ${#MISSING_SECRETS[@]} -gt 0 ]; then
        echo "   Created: ${#MISSING_SECRETS[@]} secret(s)"
    fi
else
    echo "   Created: ${#SECRETS_TO_SET[@]} secret(s)"
fi
echo ""
echo "🔍 Verify secrets at:"
echo "https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/settings/secrets/actions"
echo ""
echo "💡 Tip: Run '$0 --list-only' to check secret status anytime"
echo ""
