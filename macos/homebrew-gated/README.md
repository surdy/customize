# Homebrew Gated — Approval Wrapper for Non-Admin Users

A setup that allows non-admin macOS users to use Homebrew while requiring explicit
approval for any mutating operation (install, upgrade, uninstall, etc.). Designed to
work with AI coding agents (Copilot, Claude Code, Codex) running in autopilot/YOLO mode.

## Problem

- Non-admin user (`surdy`) can't write to `/opt/homebrew` (owned by admin user `harpreet`)
- AI agents in autopilot mode will download random binaries as workarounds
- You want Homebrew installs to always require your approval, even in YOLO mode

## Solution

Two-part setup:
1. **Admin setup** — Grant the non-admin user write access via group permissions (one-time)
2. **Wrapper setup** — Install an approval gate that intercepts mutating `brew` commands

## Quick Start

### 1. Non-admin user setup (as surdy)

```bash
# Clone and run the setup script
git clone https://github.com/surdy/customize.git
cd customize/macos/homebrew-gated
./setup.sh
```

Or have an agent do it (see [Agent Instructions](#agent-instructions) below).

### 2. Admin setup (as harpreet, one-time)

```bash
cd customize/macos/homebrew-gated
sudo ./admin-setup.sh surdy harpreet
```

Then log out and back in as surdy for group membership to take effect.

## How It Works

```
Agent calls `brew install jq`
        │
        ▼
~/.local/bin/brew (wrapper)
        │
        ├── Read-only command? (list, search, info...) → Pass through silently
        │
        └── Mutating command? (install, upgrade, uninstall...)
                │
                ├── TTY available? → Prompt: "Approve? [y/N]"
                │       │
                │       ├── y → Execute via real brew
                │       └── N → Exit with error
                │
                └── No TTY? → Print command for manual execution, exit 1
```

### Safe commands (no approval needed)

`list`, `info`, `search`, `doctor`, `config`, `--version`, `--prefix`, `--cellar`,
`--cache`, `--repository`, `leaves`, `deps`, `uses`, `desc`, `cat`, `log`, `home`,
`formulae`, `casks`, `outdated`, `commands`, `shellenv`, `completions`, `analytics`,
`tap-info`, `--env`, `help`

### Mutating commands (approval required)

`install`, `uninstall`, `upgrade`, `tap`, `untap`, `link`, `unlink`, `pin`, `unpin`,
`cleanup`, `autoremove`, `reinstall`, `edit`, `update`, `migrate`, and anything else
not in the safe list.

## Files

| File | Purpose |
|------|---------|
| `brew-wrapper.sh` | The approval wrapper script (installed as `~/.local/bin/brew`) |
| `setup.sh` | Installs the wrapper and configures PATH for the non-admin user |
| `admin-setup.sh` | One-time admin script to grant group write access to Homebrew prefix |
| `setup.sh --check` | Verify current status without making changes |

## Agent Instructions

### GitHub Copilot (CLI & Workspace)

When running as a non-admin user and a task requires installing a Homebrew package:

1. **Always use `brew install`** — never download binaries directly
2. The wrapper at `~/.local/bin/brew` will intercept and prompt for approval
3. If the wrapper isn't installed, run the setup first:
   ```bash
   git clone https://github.com/surdy/customize.git /tmp/customize
   /tmp/customize/macos/homebrew-gated/setup.sh
   export PATH="$HOME/.local/bin:$PATH"
   ```
4. If you see "No write access" errors after approval, tell the user to run the admin setup

**Copilot-specific notes:**
- The wrapper requires TTY access. In Copilot CLI, commands run in an interactive terminal so approval works natively.
- In Copilot Coding Agent (cloud), there is no TTY — the wrapper will print the command and exit. The agent should surface this to the user.

### Claude Code

When using Claude Code with the `--dangerously-skip-permissions` / YOLO mode:

1. **Always use `brew install`** — the wrapper ensures you still get approval
2. The wrapper intercepts the command and prompts via TTY (Claude Code runs in a terminal)
3. If setup is needed:
   ```bash
   git clone https://github.com/surdy/customize.git /tmp/customize
   /tmp/customize/macos/homebrew-gated/setup.sh
   export PATH="$HOME/.local/bin:$PATH"
   ```

**Claude Code-specific notes:**
- Even in YOLO mode, the wrapper's `read -p ... </dev/tty` forces an interactive prompt
- Claude Code will see the prompt output and wait — you approve/deny directly in the terminal
- Add to your Claude Code project instructions (`.claude/instructions.md`):
  ```
  When you need to install a package, always use `brew install`. Never download
  binaries directly. The brew wrapper will prompt the user for approval.
  If brew is not available or setup is needed, run:
  /path/to/customize/macos/homebrew-gated/setup.sh
  ```

### OpenAI Codex (CLI)

When using Codex in full-auto mode:

1. **Always use `brew install`** — the wrapper handles the approval gate
2. Codex runs commands in a sandbox/terminal — the wrapper will prompt if TTY is available
3. If no TTY is available, the wrapper exits with an error message showing the command to run manually

**Codex-specific notes:**
- If Codex is running in a container/sandbox without TTY, the wrapper will block the operation
  and print: `Please run this command manually: /opt/homebrew/bin/brew install <pkg>`
- Codex should surface this message to the user rather than attempting workarounds
- Setup command:
  ```bash
  git clone https://github.com/surdy/customize.git /tmp/customize
  /tmp/customize/macos/homebrew-gated/setup.sh
  export PATH="$HOME/.local/bin:$PATH"
  ```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOMEBREW_REAL_BREW` | `/opt/homebrew/bin/brew` | Path to the real brew binary |

### Intel Macs

If you're on an Intel Mac, set the real brew path:
```bash
export HOMEBREW_REAL_BREW="/usr/local/bin/brew"
```

Or edit `~/.local/bin/brew` directly after installation.

## Troubleshooting

**`brew install` fails with "Permission denied" after approval:**
- The admin setup hasn't been done yet. Ask the admin user to run `admin-setup.sh`.
- Or you logged in before the group was applied. Log out and back in.

**Wrapper not intercepting — agents call the real brew directly:**
- Check PATH order: `which -a brew` — wrapper should be first
- Some agents use absolute paths. If an agent calls `/opt/homebrew/bin/brew` directly,
  the wrapper can't intercept. Report this as a bug in the agent.

**"No interactive terminal available" in agent:**
- The agent is running without a TTY. You'll need to run the printed command manually.
- This is by design — unattended Homebrew operations are never allowed.
