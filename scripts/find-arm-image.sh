#!/usr/bin/env bash

# Script to find the latest ARM-based Oracle Linux 8 image for a given region
# Usage: ./find-arm-image.sh [region] [compartment-ocid]
# Example: ./find-arm-image.sh ap-sydney-1 ocid1.tenancy.oc1..xxx

set -euo pipefail

REGION="${1:-ap-sydney-1}"
COMPARTMENT_OCID="${2:-}"

echo "🔍 Finding latest ARM image for Oracle Linux 8 in region: $REGION"
echo ""

# Check if OCI CLI is installed
if ! command -v oci &> /dev/null; then
    echo "❌ OCI CLI not found. Please install it first:"
    echo "   https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
    echo ""
    echo "Or install via:"
    echo "   bash -c \"\$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)\""
    exit 1
fi

# Check if compartment OCID is provided
if [ -z "$COMPARTMENT_OCID" ]; then
    echo "❌ Compartment OCID not provided"
    echo ""
    echo "Usage: $0 <region> <compartment-ocid>"
    echo "Example: $0 ap-sydney-1 ocid1.tenancy.oc1..aaaaaaaxxxxx"
    echo ""
    echo "Use your tenancy OCID as compartment OCID (from OCI Console → Profile → Tenancy)"
    exit 1
fi

echo "Querying OCI API..."
echo ""

# Find latest Oracle Linux 8 ARM image
IMAGE_OCID=$(oci compute image list \
    --compartment-id "$COMPARTMENT_OCID" \
    --operating-system "Oracle Linux" \
    --operating-system-version "8" \
    --shape "VM.Standard.A1.Flex" \
    --region "$REGION" \
    --sort-by TIMECREATED \
    --sort-order DESC \
    --limit 1 \
    --query 'data[0].id' \
    --raw-output 2>/dev/null || echo "")

if [ -z "$IMAGE_OCID" ] || [ "$IMAGE_OCID" = "null" ]; then
    echo "❌ No ARM image found for region: $REGION"
    echo ""
    echo "This could mean:"
    echo "  1. The region doesn't support ARM instances"
    echo "  2. Your compartment doesn't have access"
    echo "  3. OCI CLI authentication is not configured"
    echo ""
    echo "Try a different region or check your OCI CLI config"
    exit 1
fi

# Get image details
IMAGE_NAME=$(oci compute image get \
    --image-id "$IMAGE_OCID" \
    --region "$REGION" \
    --query 'data."display-name"' \
    --raw-output 2>/dev/null || echo "Unknown")

echo "✅ Found ARM image!"
echo ""
echo "Region:       $REGION"
echo "Image Name:   $IMAGE_NAME"
echo "Image OCID:   $IMAGE_OCID"
echo ""
echo "📋 Add this to your terraform.tfvars:"
echo "   arm_image_ocid = \"$IMAGE_OCID\""
echo ""
echo "Or export as environment variable:"
echo "   export TF_VAR_arm_image_ocid=\"$IMAGE_OCID\""
