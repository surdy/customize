#!/bin/bash
# setup.sh — Install the Homebrew approval wrapper for a non-admin user.
#
# This script:
#   1. Installs the brew-wrapper.sh as ~/.local/bin/brew
#   2. Updates shell config files to put ~/.local/bin first in PATH
#   3. Works across bash, zsh, and sh
#
# Usage:
#   ./setup.sh          # Install the wrapper
#   ./setup.sh --check  # Check current status without making changes
#
# Requirements:
#   - Homebrew must already be installed (by an admin user)
#   - For `brew install` to actually work, the non-admin user needs write
#     access to the Homebrew prefix. See README.md for admin setup steps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_SOURCE="$SCRIPT_DIR/brew-wrapper.sh"
WRAPPER_DEST="$HOME/.local/bin/brew"
BREW_PREFIX="$(/opt/homebrew/bin/brew --prefix 2>/dev/null || /usr/local/bin/brew --prefix 2>/dev/null || echo "")"

# --- Helper functions ---

info()  { echo "ℹ️  $*"; }
ok()    { echo "✅ $*"; }
warn()  { echo "⚠️  $*"; }
error() { echo "❌ $*" >&2; }

check_status() {
    echo "=== Homebrew Gated Wrapper Status ==="
    echo ""

    # Check if wrapper is installed
    if [ -f "$WRAPPER_DEST" ] && [ -x "$WRAPPER_DEST" ]; then
        ok "Wrapper installed at $WRAPPER_DEST"
    else
        warn "Wrapper NOT installed at $WRAPPER_DEST"
    fi

    # Check PATH priority
    local first_brew
    first_brew="$(which brew 2>/dev/null || echo "not found")"
    if [ "$first_brew" = "$WRAPPER_DEST" ]; then
        ok "PATH is correct — wrapper takes priority"
    else
        warn "PATH issue — 'which brew' resolves to: $first_brew"
        info "Expected: $WRAPPER_DEST"
    fi

    # Check write access to Homebrew prefix
    if [ -n "$BREW_PREFIX" ]; then
        if [ -w "$BREW_PREFIX" ]; then
            ok "Write access to $BREW_PREFIX — brew install will work"
        else
            warn "No write access to $BREW_PREFIX"
            info "An admin user needs to run the group permissions setup (see README.md)"
        fi
    else
        error "Cannot determine Homebrew prefix"
    fi

    echo ""
}

install_wrapper() {
    info "Installing brew approval wrapper..."

    # Create directory
    mkdir -p "$(dirname "$WRAPPER_DEST")"

    # Copy wrapper
    if [ ! -f "$WRAPPER_SOURCE" ]; then
        error "Wrapper source not found at $WRAPPER_SOURCE"
        exit 1
    fi

    cp "$WRAPPER_SOURCE" "$WRAPPER_DEST"
    chmod +x "$WRAPPER_DEST"
    ok "Wrapper installed at $WRAPPER_DEST"
}

configure_path() {
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local comment="# Homebrew approval wrapper - must be before Homebrew in PATH"

    info "Configuring PATH in shell config files..."

    # Determine which files to update
    local configs=()

    # Always update .profile (sh/dash/bash fallback)
    configs+=("$HOME/.profile")

    # bash — use .bash_profile if it exists, otherwise .profile covers it
    if [ -f "$HOME/.bash_profile" ]; then
        configs+=("$HOME/.bash_profile")
    fi

    # zsh — use .zshenv (sourced for ALL zsh invocations)
    configs+=("$HOME/.zshenv")

    for config in "${configs[@]}"; do
        # Create file if it doesn't exist
        touch "$config"

        # Skip if already configured
        if grep -qF '.local/bin' "$config" 2>/dev/null; then
            ok "PATH already configured in $config"
            continue
        fi

        # Prepend to the file so it takes priority
        local tmp="${config}.tmp.$$"
        { echo "$comment"; echo "$path_line"; echo ""; cat "$config"; } > "$tmp"
        mv "$tmp" "$config"
        ok "PATH added to $config"
    done
}

# --- Main ---

if [ "${1:-}" = "--check" ]; then
    check_status
    exit 0
fi

echo "=== Homebrew Gated Wrapper Setup ==="
echo ""
echo "This will install an approval wrapper that intercepts mutating"
echo "brew commands (install, upgrade, uninstall, etc.) and requires"
echo "your explicit approval before proceeding."
echo ""

install_wrapper
configure_path

echo ""
echo "=== Setup Complete ==="
echo ""
info "To activate in your current shell, run:"
echo '   export PATH="$HOME/.local/bin:$PATH"'
echo ""
info "To verify, run:"
echo "   which brew   # Should show: $WRAPPER_DEST"
echo ""

# Check if we have write access
if [ -n "$BREW_PREFIX" ] && [ ! -w "$BREW_PREFIX" ]; then
    echo "─────────────────────────────────────────────────────────────"
    warn "You do NOT have write access to $BREW_PREFIX"
    info "An admin user needs to run the group permissions setup."
    info "See README.md section: 'Admin Setup (One-Time)'"
    echo "─────────────────────────────────────────────────────────────"
fi
