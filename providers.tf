# ============================================================================
# ORACLE AMPERE ALWAYS-FREE TIER CONFIGURATION
# ============================================================================
# Free Tier Limits (per tenancy):
# - Shape: VM.Standard.A1.Flex (Ampere A1 - ARM64)
# - Max OCPUs: 4 total across ALL ARM instances
# - Max Memory: 24 GB total across ALL ARM instances
# - Max Instances: Up to 4 VM instances (we use 3)
# - Boot Volume: 200 GB total (we use 150GB = 50GB × 3)
# - Public IPs: 2 reserved (we use 3 ephemeral)
# ============================================================================

# This configuration works with both Terraform and OpenTofu
# OpenTofu is recommended as it's fully open-source

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Additional providers needed for Terraform resources

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
