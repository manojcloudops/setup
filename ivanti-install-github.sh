#!/bin/bash
# Ivanti Agent Installer - Downloads from GitHub
# Auto-detects OS and installs correct version

set -e

# GitHub Configuration
GITHUB_USER="manojcloudops"
GITHUB_REPO="setup"
GITHUB_BRANCH="main"

# Base URL for raw files
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

echo "=========================================="
echo "IVANTI AGENT INSTALLER"
echo "=========================================="
echo ""

# Detect architecture
ARCH=$(uname -m)
echo "Architecture: $ARCH"

if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "❌ ERROR: ARM64 architecture not supported"
    echo "   Please contact Ivanti Support for ARM64 installer"
    exit 1
fi

if [ "$ARCH" != "x86_64" ]; then
    echo "❌ ERROR: Unsupported architecture: $ARCH"
    exit 1
fi

echo "✓ Architecture: x86_64"
echo ""

# Detect OS
echo "Detecting Operating System..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="$NAME"
    OS_VERSION="$VERSION_ID"
    echo "OS: $OS_NAME"
    echo "Version: $OS_VERSION"
else
    echo "❌ ERROR: Cannot detect OS"
    exit 1
fi

# Determine which installer to use
INSTALLER=""

# Check version first for Amazon Linux
if echo "$OS_VERSION" | grep -q "^2023"; then
    INSTALLER="ivanticloudagent-installer-amzn2023.sh"
    echo "✓ Detected: Amazon Linux 2023"
elif echo "$OS_NAME" | grep -qi "Amazon Linux 2"; then
    INSTALLER="ivanticloudagent-installer-oracle8.sh"
    echo "✓ Detected: Amazon Linux 2 (using Oracle/RHEL installer)"
elif echo "$OS_NAME" | grep -qi "Amazon"; then
    # Generic Amazon Linux - check version number
    if [ "$OS_VERSION" = "2" ]; then
        INSTALLER="ivanticloudagent-installer-oracle8.sh"
        echo "✓ Detected: Amazon Linux 2 (using Oracle/RHEL installer)"
    else
        INSTALLER="ivanticloudagent-installer-amzn2023.sh"
        echo "✓ Detected: Amazon Linux (using AL2023 installer)"
    fi
elif echo "$OS_NAME" | grep -qi "Red Hat\|CentOS\|Oracle"; then
    INSTALLER="ivanticloudagent-installer-oracle8.sh"
    echo "✓ Detected: RHEL/CentOS/Oracle Linux"
else
    echo "❌ ERROR: Unsupported OS: $OS_NAME"
    echo "   Supported: Amazon Linux 2, Amazon Linux 2023, RHEL, CentOS, Oracle Linux"
    exit 1
fi

echo ""
echo "=== Downloading Installer from GitHub ==="
mkdir -p /tmp/ivanti
cd /tmp/ivanti

DOWNLOAD_URL="${BASE_URL}/${INSTALLER}"
echo "Downloading: $INSTALLER"
echo "From: $DOWNLOAD_URL"

if curl -f -L -o "$INSTALLER" "$DOWNLOAD_URL" 2>/dev/null; then
    echo "✓ Downloaded successfully"
else
    echo "❌ ERROR: Failed to download from GitHub"
    echo ""
    echo "Please check:"
    echo "  1. File exists in repo: $INSTALLER"
    echo "  2. Repository is public or accessible"
    echo "  3. Internet connectivity"
    exit 1
fi

chmod +x "$INSTALLER"

echo ""
echo "=== Installing Ivanti Agent ==="
echo "Running installer..."
echo ""

sudo bash "$INSTALLER"
EXIT_CODE=$?

echo ""
echo "=========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ INSTALLATION COMPLETED"
    echo "=========================================="
    echo ""
    
    # Verify installation
    echo "Verifying installation..."
    
    if systemctl list-unit-files 2>/dev/null | grep -q ivanticloudagent; then
        echo "✓ Service installed"
        echo ""
        sudo systemctl status ivanticloudagent --no-pager || true
    else
        echo "⚠ Service not found - checking installation..."
    fi
    
    if [ -f /opt/ivanti/cloudagent/bin/stagentctl ]; then
        echo ""
        echo "✓ Agent binary installed at: /opt/ivanti/cloudagent"
        /opt/ivanti/cloudagent/bin/stagentctl --version 2>/dev/null || true
    fi
    
else
    echo "❌ INSTALLATION FAILED (Exit Code: $EXIT_CODE)"
    echo "=========================================="
    echo ""
    echo "Common issues:"
    echo "  1. Missing dependencies (see errors above)"
    echo "  2. Wrong installer for your OS version"
    echo "  3. Insufficient permissions"
    echo ""
    echo "Next steps:"
    echo "  1. Review error messages above"
    echo "  2. Update system: sudo yum update -y"
    echo "  3. Contact Ivanti Support if issue persists"
    echo ""
    exit $EXIT_CODE
fi

echo ""
echo "✓ Installation complete!"
