#!/bin/bash
# Claude Code Cloud Server — Bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/egerev/claude-server-setup/main/setup.sh | bash -s -- <OAUTH_TOKEN>
#
# This script installs the minimum needed to run Claude Code.
# Claude Code then handles everything else (Telegram, whisper, projects, tmux).

set -euo pipefail

TOKEN="${1:-}"

if [ -z "$TOKEN" ]; then
  echo ""
  echo "  Claude Code Cloud Server Setup"
  echo "  ───────────────────────────────"
  echo ""
  echo "  Usage:"
  echo "    curl -fsSL <url> | bash -s -- <TOKEN>"
  echo ""
  echo "  Get your token (run on your local machine):"
  echo "    claude setup-token"
  echo "    cat ~/.claude/.setup-token"
  echo ""
  exit 1
fi

echo ""
echo "  Installing Claude Code..."
echo ""

# System essentials
sudo apt-get update -qq
sudo apt-get install -y -qq git curl tmux jq ffmpeg cmake build-essential > /dev/null 2>&1

# Node.js
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - > /dev/null 2>&1
sudo apt-get install -y -qq nodejs > /dev/null 2>&1

# Bun
curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Claude Code
sudo npm install -g @anthropic-ai/claude-code > /dev/null 2>&1

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null 2>&1
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update -qq && sudo apt-get install -y -qq gh > /dev/null 2>&1

# Auth
mkdir -p ~/.claude
echo -n "$TOKEN" > ~/.claude/.setup-token
chmod 600 ~/.claude/.setup-token

# Environment
grep -q "BUN_INSTALL" ~/.bashrc 2>/dev/null || cat >> ~/.bashrc << 'BASHRC'

# Claude Code
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export CLAUDE_CODE_OAUTH_TOKEN=$(cat ~/.claude/.setup-token 2>/dev/null | tr -d '[:space:]')
BASHRC

# Clone setup repo (has CLAUDE.md with full instructions)
cd ~
rm -rf claude-server-setup 2>/dev/null
git clone https://github.com/egerev/claude-server-setup.git > /dev/null 2>&1

echo ""
echo "  ✓ Claude Code installed and authenticated"
echo ""
echo "  Now run:"
echo "    source ~/.bashrc"
echo "    cd ~/claude-server-setup"
echo "    claude --dangerously-skip-permissions"
echo ""
echo '  Then say: "set it up"'
echo ""
