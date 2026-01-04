# Security Guidelines

## 🔒 Secrets Management

### Files That Should NEVER Be Committed

The following files contain sensitive information and are excluded via `.gitignore`:

- ✅ `terraform.tfvars` - Contains your OCI credentials
- ✅ `*.tfvars` (except `*.tfvars.example`)
- ✅ `*.auto.tfvars` (except `*.auto.tfvars.example`)
- ✅ `.env` (except `.env.example`)
- ✅ `*.pem` - Private keys
- ✅ `*.key` - SSH/API keys
- ✅ `.terraform/` - May contain state with secrets
- ✅ `*.tfstate*` - Contains infrastructure state with secrets

### What's Safe to Commit

- ✅ `terraform.tfvars.example` - Template with placeholder values
- ✅ `env.example` - Template for environment variables
- ✅ `*.tf` files - Infrastructure code (no secrets)
- ✅ Documentation files

## 🛡️ Secrets in This Repository

### Oracle Cloud Credentials

Your `terraform.tfvars` contains:
- **Tenancy OCID** - Identifies your Oracle Cloud account
- **User OCID** - Identifies your user
- **Fingerprint** - API key fingerprint
- **Availability Domain** - Not secret, but specific to your account
- **Image OCIDs** - Public, but region-specific

**Risk Level:**
- 🟡 **Medium** - These OCIDs alone cannot be used without the private key
- 🔴 **High** - If combined with your `~/.oci/oci_api_key.pem` file

### Private Keys (NOT in this repo)

These files should ONLY exist locally:
- `~/.oci/oci_api_key.pem` - OCI API private key
- `~/.ssh/oracle_k3s_key` - SSH private key for instances
- `~/.ssh/oracle_k3s_key.pub` - SSH public key (less sensitive)

## ⚠️ If Secrets Are Exposed

### If You Accidentally Committed Secrets

1. **Rotate credentials immediately:**
   ```bash
   # In OCI Console:
   # 1. Go to Profile → User Settings → API Keys
   # 2. Delete the compromised key
   # 3. Generate a new key
   # 4. Update terraform.tfvars with new values
   ```

2. **Remove from git history:**
   ```bash
   # WARNING: This rewrites history!
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch terraform.tfvars" \
     --prune-empty --tag-name-filter cat -- --all
   
   # Force push (if already pushed to remote)
   git push origin --force --all
   ```

3. **Alternative: Use BFG Repo-Cleaner:**
   ```bash
   # Faster and safer
   brew install bfg
   bfg --delete-files terraform.tfvars
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   ```

### If Secrets Are Pushed to GitHub/GitLab

1. **Rotate ALL credentials immediately**
2. **Delete the repository** (if public)
3. **Create a new repository** with cleaned history
4. **Enable secret scanning** (GitHub has this built-in)

## 🔐 Best Practices

### 1. Use Environment Variables

Instead of `terraform.tfvars`, use environment variables:

```bash
# Add to ~/.zshrc or ~/.bashrc
export TF_VAR_tenancy_ocid="ocid1.tenancy..."
export TF_VAR_user_ocid="ocid1.user..."
export TF_VAR_fingerprint="xx:xx:xx..."
export TF_VAR_private_key_path="$HOME/.oci/oci_api_key.pem"
# ... etc
```

Then you don't need `terraform.tfvars` at all!

### 2. Use a Secrets Manager

For team environments:
- **1Password** - Store terraform.tfvars in 1Password
- **AWS Secrets Manager** - If using AWS
- **HashiCorp Vault** - Enterprise solution
- **SOPS** - Encrypt secrets in git

### 3. Enable Pre-commit Hooks

Install `detect-secrets` or `gitleaks`:

```bash
# Install gitleaks
brew install gitleaks

# Scan repository
gitleaks detect --source . --verbose

# Add as pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
gitleaks protect --staged --verbose
EOF
chmod +x .git/hooks/pre-commit
```

### 4. Use .gitignore Properly

Our `.gitignore` is configured to exclude:
- All `*.tfvars` files (except examples)
- All state files
- All private keys
- Terraform cache

### 5. Regular Security Audits

```bash
# Check for secrets in git history
git log -p | grep -i "ocid1\."

# Scan with gitleaks
gitleaks detect

# Check what's tracked
git ls-files | grep -E "(tfvars|\.pem|\.key)"
```

## 🚨 Current Status

✅ **Good News:**
- `terraform.tfvars` is NOT in git history
- `.gitignore` now properly excludes it
- No secrets in committed files

⚠️ **Action Required:**
- Review your `terraform.tfvars` locally
- Consider using environment variables instead
- Install pre-commit hooks for future protection

## 📚 Additional Resources

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning)
- [GitLab Secret Detection](https://docs.gitlab.com/ee/user/application_security/secret_detection/)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)

## 🎯 Summary

**What's Protected:**
- ✅ `terraform.tfvars` now in `.gitignore`
- ✅ All `*.tfvars` excluded (except examples)
- ✅ Private keys excluded
- ✅ State files excluded

**What You Should Do:**
1. ✅ Verify `.gitignore` is working: `git status`
2. ✅ Never commit `terraform.tfvars`
3. ✅ Consider using environment variables
4. ✅ Install `gitleaks` for pre-commit scanning
5. ✅ Rotate credentials if you think they were exposed

Stay safe! 🔒

