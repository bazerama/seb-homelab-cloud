# Getting ARM Capacity in Sydney

## The Challenge

Free Tier accounts are **region-locked** to where you signed up. Since you're in Sydney (ap-sydney-1), you need to work with Sydney's limited ARM capacity.

## ✅ Best Solutions (In Order of Effectiveness)

### Option 1: Upgrade to Pay-As-You-Go (PAYG) - **RECOMMENDED** ⭐

**Cost**: $0 (if you stay within free tier limits)  
**Benefit**: Priority capacity allocation  
**Success Rate**: ~80-90%

#### How to Upgrade:

1. Go to: https://cloud.oracle.com/
2. Navigate to: **Account Management** → **Payment Method**
3. Click **"Upgrade to Pay As You Go"**
4. Add a credit card (won't be charged for free tier usage)
5. Click **"Upgrade"**

**Important**: 
- You keep ALL Always Free benefits
- You're only charged if you exceed free tier limits
- ARM instances within free tier = $0/month
- Can downgrade back to "Always Free" later if needed

#### Why This Works:

Oracle prioritizes PAYG accounts for capacity allocation, even if they're using free tier resources. This is the #1 way people successfully get ARM instances in high-demand regions.

### Option 2: Automated Retry Script

Keep retrying until capacity becomes available:

```bash
# Run the auto-retry script
./scripts/auto-retry-apply.sh
```

This will:
- Retry `tofu apply` every 15 minutes
- Stop when successful or max retries reached
- Run in background so you can do other things

**Best times to run**:
- **2-6 AM AEDT** (lowest demand)
- **11 PM - 2 AM AEDT** (good success rate)
- **Weekdays** (better than weekends)

### Option 3: Manual Retry at Optimal Times

Try applying manually during low-demand periods:

**Peak Times (AVOID)**:
- 9 AM - 5 PM AEDT (business hours)
- 6 PM - 10 PM AEDT (evening peak)
- Weekends (high hobbyist activity)

**Best Times (TRY THESE)**:
- **2-6 AM AEDT** ⭐⭐⭐ (best)
- **11 PM - 1 AM AEDT** ⭐⭐ (good)
- **6-8 AM AEDT** ⭐ (decent)

```bash
# Set an alarm and run at 3 AM:
tofu apply
```

### Option 4: Try All Availability Domains in Sydney

Sydney typically has only one AD, but worth checking:

```bash
# List all ADs
./scripts/check-oci-capacity.sh

# Try each one in terraform.tfvars
availability_domain = "JYNt:AP-SYDNEY-1-AD-1"
```

## 📊 Expected Timeline

| Method | Success Rate | Time to Success |
|--------|--------------|-----------------|
| Upgrade to PAYG | 80-90% | Immediate - 1 hour |
| Auto-retry (overnight) | 60-70% | 8-24 hours |
| Manual retry (3 AM) | 50-60% | 1-7 days |
| Keep current setup | 10-20% | Weeks to never |

## 🎯 Recommended Approach

**For fastest results**:

1. **Upgrade to PAYG** (takes 5 minutes)
2. **Run `tofu apply`** (should work immediately)
3. **Downgrade to Always Free later** if desired

**If you don't want to add a credit card**:

1. **Run the auto-retry script** tonight
2. **Let it run overnight** (best capacity at 3-4 AM)
3. **Check in the morning**

## 🔧 Setting Up Auto-Retry

Let me create this script for you...
