#!/usr/bin/env bash
# Quick script to test different availability domains
# Run this if you keep getting capacity errors

echo "🔍 Trying different Availability Domains in ap-sydney-1"
echo ""

# List of ADs to try (Sydney typically has 1)
# But let's also suggest other regions

cat << 'EOF'
Sydney (ap-sydney-1) often has capacity issues. Try these alternatives:

Option 1: Try at a different time
  - Early morning: 2-6 AM AEDT
  - Late night: 11 PM - 2 AM AEDT

Option 2: Switch to a region with better capacity
  Recommended regions (update terraform.tfvars):

  1. US East (Usually best capacity):
     region = "us-ashburn-1"
     availability_domain = "zkJl:US-ASHBURN-AD-1"

  2. EU Frankfurt (Good capacity):
     region = "eu-frankfurt-1"
     availability_domain = "GvZH:EU-FRANKFURT-1-AD-1"

  3. Mumbai (Often has capacity):
     region = "ap-mumbai-1"
     availability_domain = "IooH:AP-MUMBAI-1-AD-1"

  Note: You'll also need to update arm_image_ocid for the new region

  Find image OCIDs here:
  https://docs.oracle.com/iaas/images/

Option 3: Keep retrying Sydney
  Run this command every 15-30 minutes:
  watch -n 900 'tofu apply -auto-approve'

  (This will retry every 15 minutes)

EOF
