# Claude Code — Homebrew Gated Instructions
#
# Add this to your project's .claude/instructions.md or ~/.claude/instructions.md
# to ensure Claude Code always goes through the approval wrapper.

## Package Installation Policy

- **Always use `brew install`** for installing packages. Never download binaries directly.
- A Homebrew approval wrapper is installed at `~/.local/bin/brew` that intercepts
  mutating commands and requires explicit user approval.
- If `brew` is not found or the wrapper is not set up, run:
  ```bash
  git clone https://github.com/surdy/customize.git /tmp/customize
  /tmp/customize/macos/homebrew-gated/setup.sh
  export PATH="$HOME/.local/bin:$PATH"
  ```
- If `brew install` fails with a permissions error after the user approves, the admin
  setup has not been completed. Ask the user to have their admin account run:
  ```bash
  sudo /tmp/customize/macos/homebrew-gated/admin-setup.sh surdy
  ```
- Do not attempt workarounds (curl binaries, compile from source) when brew is available.
  Surface the approval prompt to the user and wait for their decision.
