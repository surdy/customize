# Codex — Homebrew Gated Instructions
#
# Add this to your Codex project instructions or system prompt
# to ensure Codex always goes through the approval wrapper.

## Package Installation Policy

- **Always use `brew install`** for installing packages. Never download binaries directly.
- A Homebrew approval wrapper is installed at `~/.local/bin/brew` that intercepts
  mutating commands and requires explicit user approval.
- If the wrapper blocks with "No interactive terminal available", do NOT attempt
  workarounds. Instead, surface the exact command to the user:
  ```
  Please run manually: /opt/homebrew/bin/brew install <package>
  ```
- If `brew` is not found or the wrapper is not set up, run:
  ```bash
  git clone https://github.com/surdy/customize.git /tmp/customize
  /tmp/customize/macos/homebrew-gated/setup.sh
  export PATH="$HOME/.local/bin:$PATH"
  ```
- Do not download binaries from the internet as a workaround when Homebrew is available.
