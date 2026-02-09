# ============================================================================
# Billing Alerts & Budget Configuration
# ============================================================================
# This file configures budget alerts to protect against unexpected charges
# You'll receive email notifications if spending exceeds thresholds
# ============================================================================

# Budget for overall spending
resource "oci_budget_budget" "free_tier_protection" {
  compartment_id = var.tenancy_ocid
  amount         = 10 # Monthly budget cap
  reset_period   = "MONTHLY"

  display_name = "Free-Tier-Protection-Budget"
  description  = "Protects against unexpected charges - alerts at $1 and $5"

  # Target the entire tenancy
  targets = [var.tenancy_ocid]

  freeform_tags = {
    tier        = "always-free"
    managed-by  = "terraform"
    purpose     = "cost-protection"
    environment = "homelab"
  }
}

# Alert Rule: $1 threshold (Early Warning)
resource "oci_budget_alert_rule" "alert_1_dollar" {
  budget_id    = oci_budget_budget.free_tier_protection.id
  display_name = "Alert-1-Dollar-Early-Warning"
  description  = "Early warning - you've spent $1 this month"

  type           = "ACTUAL"
  threshold      = 1 # $1
  threshold_type = "ABSOLUTE"

  recipients = var.billing_alert_email

  message = <<-EOT
    ⚠️ OCI Billing Alert: $1 Threshold Reached

    Your Oracle Cloud spending has reached $1 this month.

    This is an early warning alert. Your free tier resources should be $0/month.
    If you're seeing charges:

    1. Check if you accidentally created non-free-tier resources
    2. Verify your ARM instances are using VM.Standard.A1.Flex shape
    3. Ensure you're within free tier limits (4 OCPUs, 24GB RAM)
    4. Review your OCI Console billing page

    Free tier resources this setup uses:
    - 1-3 ARM instances (VM.Standard.A1.Flex)
    - 4 OCPUs total, 24GB RAM total
    - 150GB Block Storage
    - All within Always Free limits

    Next alert: $5
  EOT

  freeform_tags = {
    tier        = "always-free"
    managed-by  = "terraform"
    purpose     = "cost-protection"
    environment = "homelab"
  }
}

# Alert Rule: $5 threshold (Urgent Warning)
resource "oci_budget_alert_rule" "alert_5_dollars" {
  budget_id    = oci_budget_budget.free_tier_protection.id
  display_name = "Alert-5-Dollars-URGENT"
  description  = "Urgent warning - you've spent $5 this month"

  type           = "ACTUAL"
  threshold      = 5 # $5
  threshold_type = "ABSOLUTE"

  recipients = var.billing_alert_email

  message = <<-EOT
    🚨 OCI Billing Alert: $5 THRESHOLD REACHED - URGENT

    Your Oracle Cloud spending has reached $5 this month!

    ACTION REQUIRED: Review your resources immediately.

    This infrastructure should be 100% free. If you're being charged:

    1. Log into OCI Console: https://cloud.oracle.com/
    2. Go to: Billing & Cost Management → Cost Analysis
    3. Identify what's causing charges
    4. Common issues:
       - Wrong instance shape (should be VM.Standard.A1.Flex)
       - Too many OCPUs (max 4 total for free tier)
       - Too much RAM (max 24GB total for free tier)
       - Additional block volumes beyond 200GB
       - Network egress over 10TB/month

    5. Consider destroying non-essential resources:
       cd seb-homelab-cloud
       tofu destroy

    Your configured setup:
    - Max 3 ARM instances (within 4 instance limit)
    - 4 OCPUs total (at limit)
    - 24GB RAM total (at limit)
    - 150GB storage (within 200GB limit)

    This should be $0/month.
  EOT

  freeform_tags = {
    tier        = "always-free"
    managed-by  = "terraform"
    purpose     = "cost-protection"
    environment = "homelab"
  }
}

# Optional: Forecast alert at 90% of $10 monthly budget
resource "oci_budget_alert_rule" "alert_forecast_90_percent" {
  budget_id    = oci_budget_budget.free_tier_protection.id
  display_name = "Alert-Forecast-90-Percent"
  description  = "Forecasted spending will reach 90% of monthly budget"

  type           = "FORECAST"
  threshold      = 90 # 90% of $10 = $9
  threshold_type = "PERCENTAGE"

  recipients = var.billing_alert_email

  message = <<-EOT
    📊 OCI Billing Forecast Alert

    Based on your current spending pattern, you're forecasted to reach
    90% of your $10 monthly budget ($9) by month end.

    This is unusual for free tier usage.

    Recommended actions:
    1. Review current spending in OCI Console
    2. Check for resources outside free tier
    3. Consider destroying test/unused resources

    Review billing: https://cloud.oracle.com/usage/reports
  EOT

  freeform_tags = {
    tier        = "always-free"
    managed-by  = "terraform"
    purpose     = "cost-protection"
    environment = "homelab"
  }
}

# Output budget information
output "budget_info" {
  description = "Budget and alert configuration"
  value = {
    budget_id        = oci_budget_budget.free_tier_protection.id
    monthly_budget   = "$10"
    alert_thresholds = "$1, $5, and 90% forecast"
    recipients       = var.billing_alert_email
    target           = "Entire tenancy"
    note             = "Free tier resources should cost $0/month"
  }
}
