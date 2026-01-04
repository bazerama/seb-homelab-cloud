#!/usr/bin/env bash

# Script to setup pre-commit hooks
# Usage: ./setup-pre-commit.sh

set -euo pipefail

echo "🪝 Pre-commit Setup Script"
echo "==========================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo -e "${YELLOW}⚠️  pre-commit not found. Installing...${NC}"

    if command -v brew &> /dev/null; then
        echo "Installing via Homebrew..."
        brew install pre-commit
    elif command -v pip3 &> /dev/null; then
        echo "Installing via pip3..."
        pip3 install pre-commit
    else
        echo -e "${RED}❌ Cannot install pre-commit automatically.${NC}"
        echo "Please install manually:"
        echo "  brew install pre-commit"
        echo "  OR"
        echo "  pip3 install pre-commit"
        exit 1
    fi
fi

echo -e "${GREEN}✅ pre-commit is installed${NC}"
echo ""

# Check if tflint is installed
if ! command -v tflint &> /dev/null; then
    echo -e "${YELLOW}⚠️  tflint not found. Installing...${NC}"

    if command -v brew &> /dev/null; then
        echo "Installing via Homebrew..."
        brew install tflint
    else
        echo -e "${YELLOW}⚠️  Install tflint manually for better validation:${NC}"
        echo "  brew install tflint"
        echo "  OR"
        echo "  curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"
    fi
else
    echo -e "${GREEN}✅ tflint is installed${NC}"
fi
echo ""

# Check if gitleaks is installed
if ! command -v gitleaks &> /dev/null; then
    echo -e "${YELLOW}⚠️  gitleaks not found. Installing...${NC}"

    if command -v brew &> /dev/null; then
        echo "Installing via Homebrew..."
        brew install gitleaks
    else
        echo -e "${YELLOW}⚠️  Install gitleaks manually for secret detection:${NC}"
        echo "  brew install gitleaks"
    fi
else
    echo -e "${GREEN}✅ gitleaks is installed${NC}"
fi
echo ""

# Check if shellcheck is installed
if ! command -v shellcheck &> /dev/null; then
    echo -e "${YELLOW}⚠️  shellcheck not found. Installing...${NC}"

    if command -v brew &> /dev/null; then
        echo "Installing via Homebrew..."
        brew install shellcheck
    else
        echo -e "${YELLOW}⚠️  Install shellcheck manually for shell script linting:${NC}"
        echo "  brew install shellcheck"
    fi
else
    echo -e "${GREEN}✅ shellcheck is installed${NC}"
fi
echo ""

# Check if markdownlint is installed
if ! command -v markdownlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  markdownlint not found. Installing...${NC}"

    if command -v npm &> /dev/null; then
        echo "Installing via npm..."
        npm install -g markdownlint-cli
    else
        echo -e "${YELLOW}⚠️  Install markdownlint manually for markdown linting:${NC}"
        echo "  npm install -g markdownlint-cli"
    fi
else
    echo -e "${GREEN}✅ markdownlint is installed${NC}"
fi
echo ""

# Install pre-commit hooks
echo "📦 Installing pre-commit hooks..."
pre-commit install

# Optional: Install commit-msg hook for conventional commits
read -p "Install commit-msg hook for conventional commits? (yes/no): " -r INSTALL_COMMITIZEN
if [[ $INSTALL_COMMITIZEN =~ ^[Yy]es$ ]]; then
    pre-commit install --hook-type commit-msg
    echo -e "${GREEN}✅ Commit-msg hook installed${NC}"
fi
echo ""

# Run hooks on all files to verify setup
echo "🧪 Testing hooks on all files..."
echo "(This may take a minute on first run)"
echo ""

if pre-commit run --all-files; then
    echo ""
    echo -e "${GREEN}✅ All hooks passed!${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  Some hooks failed or made changes.${NC}"
    echo "This is normal - hooks may have auto-fixed formatting."
    echo "Review the changes and commit them."
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 Pre-commit Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Pre-commit hooks installed:"
echo "  ✅ OpenTofu format (tofu fmt)"
echo "  ✅ OpenTofu validate"
echo "  ✅ TFLint (if installed)"
echo "  ✅ Gitleaks (secret detection)"
echo "  ✅ Trailing whitespace"
echo "  ✅ YAML validation"
echo "  ✅ Markdown lint"
echo "  ✅ ShellCheck"
echo "  ✅ No direct commits to main"
echo ""
echo "Usage:"
echo "  • Hooks run automatically on 'git commit'"
echo "  • Run manually: pre-commit run --all-files"
echo "  • Update hooks: pre-commit autoupdate"
echo "  • Skip hooks (emergency only): git commit --no-verify"
echo ""
echo "Configuration files:"
echo "  • .pre-commit-config.yaml - Hook configuration"
echo "  • .tflint.hcl - TFLint rules"
echo "  • .gitleaks.toml - Secret detection config"
echo "  • .markdownlint.json - Markdown lint rules"
echo ""
