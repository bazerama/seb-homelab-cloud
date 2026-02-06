#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Auto-Retry OpenTofu Apply
# ============================================================================
# This script will automatically retry 'tofu apply' until it succeeds
# Useful for working around OCI's "Out of host capacity" errors
# ============================================================================

RETRY_INTERVAL=900  # 15 minutes (900 seconds)
MAX_RETRIES=96      # 24 hours worth of retries (96 * 15 min = 24 hours)
LOG_FILE="retry-$(date +%Y%m%d-%H%M%S).log"

echo "🔄 OpenTofu Auto-Retry Script"
echo "============================"
echo ""
echo "Settings:"
echo "  Retry interval: ${RETRY_INTERVAL}s (15 minutes)"
echo "  Max retries: ${MAX_RETRIES} (24 hours)"
echo "  Log file: ${LOG_FILE}"
echo ""
echo "This will keep retrying 'tofu apply' until it succeeds."
echo "Press Ctrl+C to stop at any time."
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]([Ee][Ss])?$ ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Starting auto-retry loop..."
echo "Logging to: ${LOG_FILE}"
echo ""

attempt=1

while [ $attempt -le $MAX_RETRIES ]; do
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "${LOG_FILE}"
  echo "🔄 Attempt ${attempt}/${MAX_RETRIES} at ${timestamp}" | tee -a "${LOG_FILE}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "${LOG_FILE}"
  echo "" | tee -a "${LOG_FILE}"

  # Run tofu apply with auto-approve
  if tofu apply -auto-approve 2>&1 | tee -a "${LOG_FILE}"; then
    echo "" | tee -a "${LOG_FILE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "${LOG_FILE}"
    echo "✅ SUCCESS! Infrastructure deployed!" | tee -a "${LOG_FILE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
    echo "🎉 Your K3s cluster is now deploying!" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
    echo "Next steps:" | tee -a "${LOG_FILE}"
    echo "1. Wait 5-10 minutes for instances to initialize" | tee -a "${LOG_FILE}"
    echo "2. Get instance IPs: tofu output" | tee -a "${LOG_FILE}"
    echo "3. SSH to control plane: ssh ubuntu@<control-plane-ip>" | tee -a "${LOG_FILE}"
    echo "4. Check K3s: sudo kubectl get nodes" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
    echo "Log saved to: ${LOG_FILE}" | tee -a "${LOG_FILE}"
    exit 0
  fi

  # Check if the error was capacity-related
  if tail -20 "${LOG_FILE}" | grep -q "Out of host capacity"; then
    echo "" | tee -a "${LOG_FILE}"
    echo "⚠️  Capacity error detected. Retrying in ${RETRY_INTERVAL}s..." | tee -a "${LOG_FILE}"
  elif tail -20 "${LOG_FILE}" | grep -q "Error:"; then
    echo "" | tee -a "${LOG_FILE}"
    echo "❌ Non-capacity error detected!" | tee -a "${LOG_FILE}"
    echo "Please check the log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
    echo "Common issues:" | tee -a "${LOG_FILE}"
    echo "- Invalid credentials" | tee -a "${LOG_FILE}"
    echo "- Missing ARM image OCID" | tee -a "${LOG_FILE}"
    echo "- Network connectivity" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
    read -p "Continue retrying? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]([Ee][Ss])?$ ]]; then
      echo "Stopped by user." | tee -a "${LOG_FILE}"
      exit 1
    fi
  fi

  echo "" | tee -a "${LOG_FILE}"

  # Wait before next retry
  if [ $attempt -lt $MAX_RETRIES ]; then
    next_time=$(date -d "+${RETRY_INTERVAL} seconds" '+%H:%M:%S' 2>/dev/null || date -v+${RETRY_INTERVAL}S '+%H:%M:%S' 2>/dev/null || echo "soon")
    echo "⏰ Next attempt at: ${next_time}" | tee -a "${LOG_FILE}"
    echo "💤 Sleeping for ${RETRY_INTERVAL}s..." | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
    sleep ${RETRY_INTERVAL}
  fi

  attempt=$((attempt + 1))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "${LOG_FILE}"
echo "⏱️  Max retries (${MAX_RETRIES}) reached" | tee -a "${LOG_FILE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"
echo "Sydney region capacity is extremely limited." | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"
echo "Recommended next steps:" | tee -a "${LOG_FILE}"
echo "1. Upgrade to PAYG (keeps free tier, adds priority)" | tee -a "${LOG_FILE}"
echo "   Guide: SYDNEY_CAPACITY_SOLUTIONS.md" | tee -a "${LOG_FILE}"
echo "2. Try again during off-peak hours (2-6 AM AEDT)" | tee -a "${LOG_FILE}"
echo "3. Set up a cron job to keep trying automatically" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"
echo "Log saved to: ${LOG_FILE}" | tee -a "${LOG_FILE}"

exit 1
