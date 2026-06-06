#!/bin/bash
# brew-wrapper.sh — Approval gate for Homebrew mutating commands
#
# This script intercepts `brew` calls and requires interactive approval
# for any command that modifies the system (install, uninstall, upgrade, etc.).
# Read-only commands pass through silently.
#
# Install location: ~/.local/bin/brew
# Must appear in PATH before /opt/homebrew/bin (or /usr/local/bin on Intel).

REAL_BREW="${HOMEBREW_REAL_BREW:-/opt/homebrew/bin/brew}"

# Verify the real brew exists
if [ ! -x "$REAL_BREW" ]; then
    echo "ERROR: Real brew not found at $REAL_BREW" >&2
    echo "Set HOMEBREW_REAL_BREW to the correct path." >&2
    exit 1
fi

# Commands that are safe to run without approval (read-only / informational)
SAFE_COMMANDS="^(list|info|search|doctor|config|--version|--prefix|--cellar|--cache|--repository|leaves|deps|uses|desc|cat|log|home|formulae|casks|outdated|commands|shellenv|completions|analytics|tap-info|--env|help)$"

if [[ "$1" =~ $SAFE_COMMANDS ]]; then
    exec "$REAL_BREW" "$@"
fi

# Also allow `autoremove --dry-run` (read-only variant)
if [[ "$1" == "autoremove" && "$*" == *"--dry-run"* ]]; then
    exec "$REAL_BREW" "$@"
fi

# For mutating commands, require explicit approval
echo "" >&2
echo "╔══════════════════════════════════════════════════════════╗" >&2
echo "║  🍺 HOMEBREW APPROVAL REQUIRED                          ║" >&2
echo "╠══════════════════════════════════════════════════════════╣" >&2
echo "║                                                          ║" >&2
printf "║  Command: brew %s\n" "$*" >&2
echo "║                                                          ║" >&2
echo "╚══════════════════════════════════════════════════════════╝" >&2
echo "" >&2

# Check if we have a TTY for interactive approval
if [ -t 0 ] || [ -t 2 ]; then
    read -p "Approve this Homebrew operation? [y/N] " -n 1 -r </dev/tty
    echo "" >&2
else
    # No TTY — likely running in a non-interactive / headless agent context
    echo "⚠️  No interactive terminal available for approval." >&2
    echo "   This command requires manual execution:" >&2
    echo "" >&2
    echo "   $REAL_BREW $*" >&2
    echo "" >&2
    echo "   Run the above command in a terminal, then retry your task." >&2
    exit 1
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    exec "$REAL_BREW" "$@"
else
    echo "❌ Homebrew operation denied by user." >&2
    exit 1
fi
