#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Find ARM Image OCID for OCI Region
# ============================================================================
# This script helps find the correct Ubuntu ARM image OCID for your region
# ============================================================================

REGION="${1:-us-ashburn-1}"

echo "🔍 Finding ARM Ubuntu Image for Region: ${REGION}"
echo ""

# Check if OCI CLI is installed
if ! command -v oci &>/dev/null; then
  echo "⚠️  OCI CLI not installed."
  echo ""
  echo "Manual method:"
  echo "1. Go to: https://docs.oracle.com/iaas/images/"
  echo "2. Select region: ${REGION}"
  echo "3. Find: Canonical Ubuntu 22.04 (ARM)"
  echo "4. Copy the OCID"
  echo ""
  echo "Or install OCI CLI:"
  echo "  macOS: brew install oci-cli"
  echo "  Then run: oci setup config"
  exit 1
fi

# Check if OCI CLI is configured
if [ ! -f ~/.oci/config ]; then
  echo "⚠️  OCI CLI not configured."
  echo ""
  echo "Run: oci setup config"
  echo ""
  echo "Manual method:"
  echo "1. Go to: https://docs.oracle.com/iaas/images/"
  echo "2. Select region: ${REGION}"
  echo "3. Find: Canonical Ubuntu 22.04 (ARM)"
  echo "4. Copy the OCID"
  exit 1
fi

echo "Searching for Ubuntu 22.04 ARM images..."
echo ""

# Get compartment from terraform.tfvars
COMPARTMENT_OCID=$(grep "^compartment_ocid" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "' | head -1)

# Search for ARM Ubuntu images
oci compute image list \
  --compartment-id "${COMPARTMENT_OCID}" \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "22.04" \
  --shape "VM.Standard.A1.Flex" \
  --region "${REGION}" \
  --query 'data[].{"Name":"display-name","OCID":"id"}' \
  --output table 2>/dev/null || {
    echo "❌ Failed to query OCI"
    echo ""
    echo "Manual method:"
    echo "1. Go to: https://docs.oracle.com/iaas/images/"
    echo "2. Select region: ${REGION}"
    echo "3. Find: Canonical Ubuntu 22.04 Minimal aarch64"
    echo "4. Copy the OCID"
    echo ""
    echo "Or try the OCI Console:"
    echo "1. Go to: Compute -> Instances -> Create Instance"
    echo "2. Click 'Change Image'"
    echo "3. Select: Canonical Ubuntu 22.04 Minimal aarch64"
    echo "4. The OCID will be shown"
    exit 1
  }

echo ""
echo "📋 Update terraform.tfvars with the OCID from above"
echo ""
