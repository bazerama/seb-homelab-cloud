#!/usr/bin/env bash

# Script to automatically update GitHub Secrets from terraform.tfvars
# Usage: ./scripts/update-github-secrets.sh

set -euo pipefail

echo "🔐 Update GitHub Secrets from terraform.tfvars"
echo "==============================================="

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "Install it: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

echo "✅ gh CLI is authenticated"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found!"
    echo "Please run this script from the repository root."
    exit 1
fi

# Function to extract value from tfvars and clean it
get_tfvar() {
  local var_name=$1
  # Extract value, strip quotes, and remove inline comments
  grep "^${var_name}" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "' | xargs
}

# Function to get file content
get_file_content() {
  local path=$1
  local expanded_path="${path/#\~/$HOME}"
  if [ -f "$expanded_path" ]; then
    cat "$expanded_path"
  else
    echo "ERROR: File not found at $expanded_path"
    exit 1
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

# Verify required values
if [ -z "$TENANCY_OCID" ] || [ -z "$REGION" ] || [ -z "$BILLING_EMAIL" ]; then
    echo "❌ Missing required values in terraform.tfvars"
    echo "Please ensure all variables are set correctly"
    exit 1
fi

echo "📊 Values to be set:"
echo "  • Region: $REGION"
echo "  • Availability Domain: $AVAILABILITY_DOMAIN"
echo "  • Billing Email: $BILLING_EMAIL"
echo "  • ARM Image OCID: ${ARM_IMAGE_OCID:0:30}..."
echo ""

read -p "Update GitHub secrets with these values? (yes/no): " -r REPLY
echo ""
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "❌ Cancelled"
    exit 0
fi

echo "🚀 Updating GitHub Secrets..."
echo ""

# Set secrets one by one
gh secret set OCI_TENANCY_OCID --body "$TENANCY_OCID"
echo "✅ OCI_TENANCY_OCID"

gh secret set OCI_USER_OCID --body "$USER_OCID"
echo "✅ OCI_USER_OCID"

gh secret set OCI_FINGERPRINT --body "$FINGERPRINT"
echo "✅ OCI_FINGERPRINT"

gh secret set OCI_COMPARTMENT_OCID --body "$COMPARTMENT_OCID"
echo "✅ OCI_COMPARTMENT_OCID"

gh secret set OCI_REGION --body "$REGION"
echo "✅ OCI_REGION"

gh secret set OCI_AVAILABILITY_DOMAIN --body "$AVAILABILITY_DOMAIN"
echo "✅ OCI_AVAILABILITY_DOMAIN"

gh secret set OCI_ARM_IMAGE_OCID --body "$ARM_IMAGE_OCID"
echo "✅ OCI_ARM_IMAGE_OCID"

gh secret set OCI_BILLING_ALERT_EMAIL --body "$BILLING_EMAIL"
echo "✅ OCI_BILLING_ALERT_EMAIL (NEW!)"

gh secret set OCI_PRIVATE_KEY --body "$PRIVATE_KEY"
echo "✅ OCI_PRIVATE_KEY"

gh secret set SSH_PUBLIC_KEY --body "$SSH_PUBLIC_KEY"
echo "✅ SSH_PUBLIC_KEY"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ GitHub Secrets Updated Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔍 Verify at:"
echo "https://github.com/bazerama/seb-homelab-cloud/settings/secrets/actions"
echo ""
echo "💡 Next: Your GitHub Actions will now use Sydney region!"
