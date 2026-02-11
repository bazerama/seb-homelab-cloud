#!/usr/bin/env bash

# Script to remove terraform.tfvars from git history
# Usage: ./clean-git-history-fixed.sh

set -euo pipefail

echo "🧹 Git History Cleanup Script (Fixed)"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}⚠️  WARNING: This will rewrite git history!${NC}"
echo ""
echo "This script will:"
echo "  1. Remove terraform.tfvars from all git history"
echo "  2. Clean up all references"
echo "  3. Garbage collect to fully remove data"
echo ""
echo "Before running this:"
echo "  ✅ Rotate your OCI API key (the old one is compromised)"
echo "  ✅ Update terraform.tfvars with new credentials"
echo "  ✅ Backup your repository"
echo ""
read -p "Have you rotated your credentials? (yes/no): " -r REPLY
echo ""
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo -e "${RED}Please rotate credentials first using:${NC}"
    echo "  ./scripts/rotate-oci-keys.sh"
    exit 1
fi

# Check if terraform.tfvars exists in history (FIXED)
echo "🔍 Checking git history for terraform.tfvars..."
TFVARS_HISTORY=$(git log --all --full-history --oneline -- terraform.tfvars 2>/dev/null || true)

if [ -n "$TFVARS_HISTORY" ]; then
    echo -e "${RED}⚠️  Found terraform.tfvars in git history:${NC}"
    echo "$TFVARS_HISTORY"
    echo ""

    # Show the actual content from the first commit
    FIRST_COMMIT=$(echo "$TFVARS_HISTORY" | tail -1 | cut -d' ' -f1)
    echo -e "${YELLOW}Showing first 10 lines from commit $FIRST_COMMIT:${NC}"
    git show "$FIRST_COMMIT:terraform.tfvars" 2>/dev/null | head -10 || echo "(Could not read file)"
    echo ""
else
    echo -e "${GREEN}✅ terraform.tfvars not found in git history${NC}"
    echo "Nothing to clean!"
    exit 0
fi

# Check if pushed to remote
echo "🔍 Checking remotes..."
if git remote -v | grep -q .; then
    echo -e "${YELLOW}Remotes found:${NC}"
    git remote -v
    echo ""
    echo -e "${RED}⚠️  If you've pushed to remote, the secrets may be public!${NC}"
    echo "After cleaning, you'll need to force push:"
    echo "  git push origin --force --all"
    echo ""
    read -p "Continue with cleanup? (yes/no): " -r CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]es$ ]]; then
        exit 1
    fi
fi
echo ""

# Method selection
echo "Choose cleanup method:"
echo "  1) git filter-branch (built-in, slower)"
echo "  2) BFG Repo-Cleaner (faster, needs installation)"
echo ""
read -p "Select method (1 or 2): " -r METHOD
echo ""

if [ "$METHOD" = "2" ]; then
    # Check if BFG is installed
    if ! command -v bfg &> /dev/null; then
        echo -e "${YELLOW}BFG not found. Installing via Homebrew...${NC}"
        if command -v brew &> /dev/null; then
            brew install bfg
        else
            echo -e "${RED}Homebrew not found. Please install BFG manually:${NC}"
            echo "  https://rtyley.github.io/bfg-repo-cleaner/"
            echo ""
            echo "Or use method 1 (git filter-branch)"
            exit 1
        fi
    fi

    echo "🧹 Cleaning with BFG Repo-Cleaner..."
    bfg --delete-files terraform.tfvars
    echo ""

elif [ "$METHOD" = "1" ]; then
    echo "🧹 Cleaning with git filter-branch..."
    git filter-branch --force --index-filter \
      "git rm --cached --ignore-unmatch terraform.tfvars" \
      --prune-empty --tag-name-filter cat -- --all
    echo ""
else
    echo -e "${RED}Invalid method selected${NC}"
    exit 1
fi

# Clean up
echo "🗑️  Cleaning up references..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive
echo ""

# Verify
echo "✅ Verifying cleanup..."
TFVARS_AFTER=$(git log --all --full-history --oneline -- terraform.tfvars 2>/dev/null || true)

if [ -n "$TFVARS_AFTER" ]; then
    echo -e "${RED}❌ terraform.tfvars still found in history!${NC}"
    echo "$TFVARS_AFTER"
    echo "Please check manually or try a different method"
    exit 1
else
    echo -e "${GREEN}✅ terraform.tfvars removed from git history${NC}"
fi
echo ""

# Check if gitignore is properly configured
echo "🔍 Checking .gitignore..."
if git check-ignore -q terraform.tfvars; then
    echo -e "${GREEN}✅ terraform.tfvars is properly ignored${NC}"
else
    echo -e "${RED}❌ terraform.tfvars is NOT in .gitignore!${NC}"
    echo "This should not happen. Please add it to .gitignore"
    exit 1
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 Cleanup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Verify cleanup: git log --all -- terraform.tfvars"
echo "  2. Test your repo: tofu plan"
echo ""

if git remote -v | grep -q .; then
    echo "  3. Force push to remote:"
    echo "     git push origin --force --all"
    echo "     git push origin --force --tags"
    echo ""
    echo -e "${RED}⚠️  Force pushing will rewrite remote history!${NC}"
    echo "     Coordinate with anyone else using this repo."
    echo ""
    read -p "Push to remote now? (yes/no): " -r PUSH_REPLY
    if [[ $PUSH_REPLY =~ ^[Yy]es$ ]]; then
        git push origin --force --all
        git push origin --force --tags
        echo -e "${GREEN}✅ Pushed to remote${NC}"
    else
        echo "Remember to push manually later!"
    fi
fi
echo ""
echo "✅ Your credentials have been removed from git history"
echo "✅ Make sure you've rotated your API key in OCI Console"
echo ""
