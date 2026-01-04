# Why OpenTofu?

This project uses [OpenTofu](https://opentofu.org/), the open-source alternative to Terraform.

## 🤔 What is OpenTofu?

OpenTofu is a fork of Terraform that happened after HashiCorp changed Terraform's license from open-source (MPL 2.0) to Business Source License (BSL) in August 2023.

### Key Points

- **100% Open Source**: MPL 2.0 licensed (truly open)
- **Community-Driven**: Linux Foundation project
- **Terraform Compatible**: Drop-in replacement for Terraform
- **Same Syntax**: Uses HCL (HashiCorp Configuration Language)
- **Same Providers**: Works with all Terraform providers
- **Better Future**: Community governance, no vendor lock-in

## 📊 OpenTofu vs Terraform

| Feature | OpenTofu | Terraform |
|---------|----------|-----------|
| **License** | MPL 2.0 (Open Source) ✅ | BSL (Source Available) ⚠️ |
| **Governance** | Linux Foundation ✅ | HashiCorp (single vendor) |
| **Community** | Community-driven ✅ | Corporate-driven |
| **Cost** | Free forever ✅ | Free for now, could change |
| **Compatibility** | Compatible with Terraform | Compatible with older OpenTofu |
| **Providers** | All Terraform providers ✅ | All Terraform providers ✅ |
| **State Format** | Compatible ✅ | Compatible ✅ |
| **Performance** | Same/Better | Same |
| **Updates** | Rapid community updates | Corporate schedule |

## 🚀 Why We Use OpenTofu

1. **True Open Source**: Will always remain open source
2. **No Vendor Lock-in**: Community-governed, not controlled by one company
3. **Better for Homelab**: Free forever, no licensing concerns
4. **Drop-in Replacement**: Works exactly like Terraform
5. **Future-Proof**: Won't have license changes down the road

## 📦 Installation

### macOS

```bash
# Homebrew
brew install opentofu

# Verify
tofu version
```

### Linux

```bash
# Snap
snap install --classic opentofu

# Or Debian/Ubuntu
curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh

# Or Arch
yay -S opentofu-bin

# Verify
tofu version
```

### Other Options

See: https://opentofu.org/docs/intro/install/

## 🔄 Migrating from Terraform

If you already have Terraform installed, OpenTofu is a drop-in replacement:

```bash
# Instead of:
terraform init
terraform plan
terraform apply

# Use:
tofu init
tofu plan
tofu apply
```

### State Migration

OpenTofu can read Terraform state files directly:

```bash
# If you have existing Terraform state
tofu init
tofu plan  # Will read existing .tfstate file
```

No migration needed! Just start using `tofu` instead of `terraform`.

## 🛠️ This Project's Setup

### Makefile Auto-Detection

Our Makefile automatically detects whether you have OpenTofu or Terraform:

```makefile
TOFU := $(shell command -v tofu 2> /dev/null)
ifndef TOFU
	TOFU := $(shell command -v terraform 2> /dev/null)
endif
```

This means:
- ✅ If you have OpenTofu → uses `tofu`
- ✅ If you have Terraform → uses `terraform`
- ✅ Same commands work for both!

### Using the Makefile

```bash
make version  # Shows which one you're using
make init     # Works with both
make plan     # Works with both
make deploy   # Works with both
```

## 🤝 Compatibility

### Provider Compatibility

OpenTofu uses the same provider ecosystem as Terraform:

```hcl
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"  # Same provider!
      version = "~> 5.0"
    }
  }
}
```

### State File Compatibility

- ✅ OpenTofu can read Terraform state files
- ✅ Terraform can read OpenTofu state files (for now)
- ✅ Same format, fully compatible

### Module Compatibility

- ✅ OpenTofu works with Terraform modules from registry
- ✅ Same HCL syntax
- ✅ No changes needed

## 📚 Resources

- **Official Website**: https://opentofu.org/
- **Documentation**: https://opentofu.org/docs/
- **GitHub**: https://github.com/opentofu/opentofu
- **Community**: https://opentofu.org/community/
- **Provider Registry**: https://github.com/opentofu/registry

## 💡 Pro Tips

### Alias for Easier Migration

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# If you're used to typing 'terraform'
alias terraform='tofu'

# Or keep both
alias tf='tofu'
```

### Version Management

Use `tenv` (like `tfenv` but for OpenTofu):

```bash
# Install tenv
brew install tofuutils/tap/tenv

# Install specific OpenTofu version
tenv tofu install 1.6.0
tenv tofu use 1.6.0
```

### IDE Support

Most Terraform IDE extensions work with OpenTofu:

- **VSCode**: HashiCorp Terraform extension (works with OpenTofu)
- **IntelliJ**: Terraform plugin (works with OpenTofu)
- **Vim**: terraform.vim (works with OpenTofu)

Just configure them to use `tofu` instead of `terraform`.

## ❓ FAQ

### Can I use Terraform instead?

Yes! This project works with both:
- Use `terraform` commands if you prefer
- The Makefile detects both automatically
- All `.tf` files are compatible

### Will my Terraform state work?

Yes! OpenTofu reads Terraform state files without any migration needed.

### Is OpenTofu stable?

Yes! It's based on Terraform 1.6.x, which is very stable. The OpenTofu team includes many former Terraform core contributors.

### What about Terraform 1.7+?

OpenTofu includes all Terraform 1.6 features plus additional community features. For homelab use, you won't notice any difference.

### Can I contribute?

Yes! OpenTofu is community-driven:
- GitHub: https://github.com/opentofu/opentofu
- Issues, PRs welcome
- Community governance

## 🎯 Recommendation

For homelab and personal projects: **Use OpenTofu**
- It's free and open source (always will be)
- No vendor lock-in
- Community-driven development
- Drop-in Terraform replacement

For enterprise with existing Terraform setup: **Your choice**
- Both work exactly the same way
- Easy to switch later if needed
- No technical differences for most use cases

---

**Bottom line**: OpenTofu is the open-source future of Terraform. Use it! 🚀

