#!/bin/bash
# admin-setup.sh — One-time setup to grant a non-admin user write access to Homebrew.
#
# This script must be run by an admin user (or with sudo).
# It creates a shared group, adds users to it, and sets permissions
# on the Homebrew prefix so non-admin users can run `brew install`.
#
# Usage (run as admin user):
#   sudo ./admin-setup.sh <non-admin-username> [admin-username]
#
# Example:
#   sudo ./admin-setup.sh surdy harpreet

set -euo pipefail

NON_ADMIN_USER="${1:-}"
ADMIN_USER="${2:-$(whoami)}"
GROUP_NAME="brew"

if [ -z "$NON_ADMIN_USER" ]; then
    echo "Usage: sudo $0 <non-admin-username> [admin-username]"
    echo ""
    echo "Example: sudo $0 surdy harpreet"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo or as root."
    echo "Usage: sudo $0 $NON_ADMIN_USER $ADMIN_USER"
    exit 1
fi

# Determine Homebrew prefix
BREW_PREFIX="$(/opt/homebrew/bin/brew --prefix 2>/dev/null || /usr/local/bin/brew --prefix 2>/dev/null || echo "")"
if [ -z "$BREW_PREFIX" ]; then
    echo "ERROR: Cannot determine Homebrew prefix. Is Homebrew installed?"
    exit 1
fi

echo "=== Homebrew Shared Access Setup ==="
echo ""
echo "  Homebrew prefix:  $BREW_PREFIX"
echo "  Group:            $GROUP_NAME"
echo "  Admin user:       $ADMIN_USER"
echo "  Non-admin user:   $NON_ADMIN_USER"
echo ""

# Create group if it doesn't exist
if dseditgroup -o read "$GROUP_NAME" &>/dev/null; then
    echo "ℹ️  Group '$GROUP_NAME' already exists"
else
    echo "Creating group '$GROUP_NAME'..."
    dseditgroup -o create "$GROUP_NAME"
    echo "✅ Group created"
fi

# Add users to group
for user in "$ADMIN_USER" "$NON_ADMIN_USER"; do
    if dseditgroup -o checkmember -m "$user" "$GROUP_NAME" &>/dev/null; then
        echo "ℹ️  $user is already a member of '$GROUP_NAME'"
    else
        echo "Adding $user to '$GROUP_NAME'..."
        dseditgroup -o edit -a "$user" -t user "$GROUP_NAME"
        echo "✅ $user added"
    fi
done

# Set group ownership on Homebrew prefix
echo ""
echo "Setting group ownership on $BREW_PREFIX..."
chgrp -R "$GROUP_NAME" "$BREW_PREFIX"
echo "✅ Group ownership set"

# Set group write permissions
echo "Setting group write permissions..."
chmod -R g+w "$BREW_PREFIX"
echo "✅ Group write permissions set"

# Set setgid on directories so new files inherit the group
echo "Setting setgid on directories..."
find "$BREW_PREFIX" -type d -exec chmod g+s {} +
echo "✅ Setgid applied to directories"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "⚠️  IMPORTANT: $NON_ADMIN_USER must log out and back in for"
echo "   group membership to take effect."
echo ""
echo "To verify (as $NON_ADMIN_USER after re-login):"
echo "   groups | grep $GROUP_NAME"
echo "   touch $BREW_PREFIX/.write_test && rm $BREW_PREFIX/.write_test && echo OK"
