# GitHub Actions Workflows

## OpenTofu CI/CD

Automated infrastructure deployment using OpenTofu (Terraform).

### Workflow Triggers

1. **Push to main** - Automatically validates and applies changes
2. **Pull Requests** - Validates and plans changes, posts plan as PR comment
3. **Manual (workflow_dispatch)** - Run plan, apply, or destroy manually

### Required Secrets

Configure these in **Settings → Secrets and variables → Actions → Repository secrets**:

#### OCI Authentication
- `OCI_TENANCY_OCID` - Your Oracle Cloud tenancy OCID
- `OCI_USER_OCID` - Your Oracle Cloud user OCID
- `OCI_FINGERPRINT` - API key fingerprint
- `OCI_PRIVATE_KEY` - API private key (contents of `~/.oci/oci_api_key.pem`)
- `OCI_COMPARTMENT_OCID` - Compartment OCID (usually same as tenancy)

#### OCI Configuration
- `OCI_REGION` - Oracle Cloud region (e.g., `ap-sydney-1`)
- `OCI_AVAILABILITY_DOMAIN` - Availability domain (e.g., `JYNt:AP-SYDNEY-1-AD-1`)
- `OCI_ARM_IMAGE_OCID` - ARM image OCID for your region

#### SSH Configuration
- `SSH_PUBLIC_KEY` - SSH public key for instance access (contents of `~/.ssh/oracle_k3s_key.pub`)

### Setting Up Secrets

#### 1. Get Your Values

```bash
# Source your existing terraform.tfvars (or get from OCI Console)
cd /Users/seb/repos/seb-homelab-cloud

# Display values (without showing private key)
echo "OCI_TENANCY_OCID=$(grep tenancy_ocid terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
echo "OCI_USER_OCID=$(grep user_ocid terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
echo "OCI_FINGERPRINT=$(grep fingerprint terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
echo "OCI_COMPARTMENT_OCID=$(grep compartment_ocid terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
echo "OCI_REGION=$(grep region terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
echo "OCI_AVAILABILITY_DOMAIN=$(grep availability_domain terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
echo "OCI_ARM_IMAGE_OCID=$(grep arm_image_ocid terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"

# Private key (CAREFUL - this is sensitive!)
cat ~/.oci/oci_api_key.pem

# SSH public key
cat ~/.ssh/oracle_k3s_key.pub
```

#### 2. Add to GitHub

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:
   - Name: `OCI_TENANCY_OCID`
   - Secret: (paste the value)
   - Click **Add secret**
5. Repeat for all secrets listed above

#### 3. Protect Production

1. Go to **Settings** → **Environments**
2. Create environment: `production`
3. Add protection rules:
   - ✅ Required reviewers (add yourself)
   - ✅ Wait timer (optional): 0 minutes
4. Save protection rules

This ensures manual approval is required before applying changes.

### Usage

#### Automatic (on push to main)
```bash
git add main.tf
git commit -m "feat: update infrastructure"
git push origin main
# Workflow runs automatically
# Requires approval in "production" environment
```

#### Pull Request Flow
```bash
git checkout -b feature/new-config
git add main.tf
git commit -m "feat: add new configuration"
git push origin feature/new-config
# Create PR on GitHub
# Workflow validates and posts plan as PR comment
```

#### Manual Execution

1. Go to **Actions** tab
2. Select **OpenTofu CI/CD**
3. Click **Run workflow**
4. Choose action:
   - `plan` - View what would change
   - `apply` - Apply changes (requires approval)
   - `destroy` - Destroy all infrastructure (requires approval)

### Workflow Jobs

#### 1. Validate
- Runs on all triggers
- Checks:
  - ✅ Format (`tofu fmt -check`)
  - ✅ Initialize (`tofu init`)
  - ✅ Validate (`tofu validate`)
- Posts comment on PR if format check fails

#### 2. Plan
- Runs on PRs and manual dispatch
- Creates execution plan
- Posts plan output as PR comment
- Uploads plan artifact

#### 3. Apply
- Runs on push to main or manual dispatch
- Requires `production` environment approval
- Applies infrastructure changes
- Outputs cluster information

#### 4. Destroy
- Only runs via manual dispatch
- Requires `production` environment approval
- Destroys all infrastructure

### Artifacts

- **tfplan** - Terraform plan file (retained for 7 days)
- Can be downloaded and applied locally if needed

### Security Considerations

✅ **Secrets are never exposed in logs**
- All sensitive values use GitHub Secrets
- OpenTofu output is sanitized (sensitive values hidden)

✅ **Environment protection**
- `production` environment requires manual approval
- Prevents accidental infrastructure changes

✅ **SSH keys**
- Only public key is stored in secrets
- Private key remains on your local machine

⚠️ **Important Notes**
- Never commit `terraform.tfvars` to the repository
- Never expose secrets in PR comments
- Always review plans before approving apply

### Troubleshooting

#### "Invalid private key format"
- Ensure you copied the entire private key including Header and Footer

#### "Authentication failed"
- Verify fingerprint matches the key in OCI Console
- Check that user OCID and tenancy OCID are correct
- Ensure API key is still active in OCI Console

#### "Capacity unavailable"
- ARM instances in free tier are limited
- Try different availability domain
- Workflow will fail but you can retry later

#### "Format check failed"
- Run locally: `tofu fmt -recursive`
- Commit the formatted files

### Local Development

You can still use OpenTofu locally:

```bash
# Use your local terraform.tfvars
tofu plan
tofu apply

# Or use environment variables
export TF_VAR_tenancy_ocid="..."
tofu plan
```

The workflow uses the same configuration, just via GitHub Secrets.

### Best Practices

1. **Always create a PR** for infrastructure changes
2. **Review the plan** before approving apply
3. **Keep secrets rotated** - update GitHub secrets when you rotate OCI keys
4. **Test locally first** before pushing to main
5. **Use descriptive commit messages** following conventional commits

### Example Workflow

```bash
# 1. Create feature branch
git checkout -b feature/add-load-balancer

# 2. Make changes
vim main.tf

# 3. Test locally
tofu plan

# 4. Commit and push
git add main.tf
git commit -m "feat(infra): add OCI load balancer"
git push origin feature/add-load-balancer

# 5. Create PR on GitHub
# - Workflow runs validation and plan
# - Review plan in PR comment
# - Merge PR after approval

# 6. Workflow runs on main
# - Requires approval in "production" environment
# - Apply runs automatically after approval
```

### Monitoring

- **Actions tab** - View all workflow runs
- **Email notifications** - GitHub sends emails on workflow failures
- **Status badges** - Add to README:
  ```markdown
  ![OpenTofu](https://github.com/bazerama/seb-homelab-cloud/actions/workflows/opentofu.yml/badge.svg)
  ```

---

**Questions?** Check the [OpenTofu documentation](https://opentofu.org/docs/) or [GitHub Actions docs](https://docs.github.com/en/actions).
