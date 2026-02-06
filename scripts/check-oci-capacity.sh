#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Oracle Cloud Capacity Checker
# ============================================================================
# This script helps find available capacity in Oracle Cloud Free Tier
# by checking different availability domains.
#
# Usage: ./scripts/check-oci-capacity.sh
# ============================================================================

echo "🔍 Oracle Cloud Capacity Checker"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
  echo -e "${RED}❌ Error: terraform.tfvars not found${NC}"
  exit 1
fi

# Extract region from terraform.tfvars
REGION=$(grep "^region" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "')

echo "📍 Current Region: ${REGION}"
echo ""

# Check if OCI CLI is installed
if ! command -v oci &>/dev/null; then
  echo -e "${YELLOW}⚠️  OCI CLI not installed. Installing instructions:${NC}"
  echo ""
  echo "macOS:"
  echo "  brew install oci-cli"
  echo ""
  echo "Linux:"
  echo "  bash -c \"\$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)\""
  echo ""
  exit 1
fi

# Check if OCI CLI is configured
if [ ! -f ~/.oci/config ]; then
  echo -e "${YELLOW}⚠️  OCI CLI not configured. Run:${NC}"
  echo "  oci setup config"
  echo ""
  exit 1
fi

echo "📋 Listing Availability Domains in ${REGION}..."
echo ""

# Get tenancy OCID
TENANCY_OCID=$(grep "^tenancy_ocid" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "')

# List availability domains
ADS=$(oci iam availability-domain list \
  --compartment-id "${TENANCY_OCID}" \
  --query 'data[].name' \
  --raw-output 2>/dev/null | tr '\t' '\n')

if [ -z "$ADS" ]; then
  echo -e "${RED}❌ Failed to list availability domains${NC}"
  echo "Please check your OCI CLI configuration."
  exit 1
fi

echo -e "${GREEN}✅ Found Availability Domains:${NC}"
echo ""

AD_COUNT=1
for AD in $ADS; do
  echo "${AD_COUNT}. ${AD}"
  AD_COUNT=$((AD_COUNT + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Recommendations:"
echo ""
echo "1. Try different availability domains:"
echo "   Update terraform.tfvars with a different AD from the list above"
echo ""
echo "2. Try at different times:"
echo "   Oracle's capacity changes frequently - try early morning or late night"
echo ""
echo "3. Try different regions with better capacity:"
echo "   - us-ashburn-1 (US East)"
echo "   - eu-frankfurt-1 (EU Central)"
echo "   - ap-mumbai-1 (India)"
echo "   - uk-london-1 (UK)"
echo ""
echo "4. Deploy incrementally:"
echo "   Start with 1 control plane node, then add workers one at a time"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔧 Quick Fix:"
echo ""
echo "Edit terraform.tfvars and change the availability_domain line to:"
echo ""
for AD in $ADS; do
  CURRENT_AD=$(grep "^availability_domain" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "')
  if [ "$AD" != "$CURRENT_AD" ]; then
    echo -e "${GREEN}availability_domain = \"${AD}\"${NC}"
  fi
done
echo ""
echo "Then run: tofu plan"
echo ""
