# Claude Server Setup

One-command setup for running Claude Code with Telegram on a cloud server. Control your projects from your phone — send text and voice messages, get AI responses, manage code.

## What You Get

- **Claude Code** running 24/7 on a cloud server (doesn't sleep when your laptop closes)
- **Telegram integration** — chat with Claude from your phone via Telegram bots
- **Voice messages** — speak into Telegram, Claude reads the transcription (local Whisper, no API keys)
- **Multi-project** — separate Telegram bots for each project, isolated sessions
- **Tailscale** (optional) — route traffic through your home IP

## Prerequisites

1. **Claude subscription** (Pro, Max, Team, or Enterprise)
2. **A VPS** — Ubuntu 22.04+ (recommended: 4GB RAM, any provider)
3. **A Telegram bot token** — create via [@BotFather](https://t.me/BotFather)

## Setup

### Step 1: Get your auth token (on your local machine)

```bash
claude setup-token
```

This opens a browser, you authenticate, and it saves a long-lived token (~1 year) to `~/.claude/.setup-token`. Copy it:

```bash
cat ~/.claude/.setup-token
```

### Step 2: Run setup on your server

SSH into your VPS and run:

```bash
curl -fsSL https://raw.githubusercontent.com/egerev/claude-server-setup/main/setup.sh | bash -s -- <YOUR_TOKEN>
```

Replace `<YOUR_TOKEN>` with the token from Step 1.

**Options:**
```bash
# With medium whisper model (better for Russian, 1.5GB):
curl -fsSL ... | bash -s -- <TOKEN> medium

# With tiny model (fast, 75MB, English-only):
curl -fsSL ... | bash -s -- <TOKEN> tiny
```

### Step 3: Configure Telegram

```bash
source ~/.bashrc
cd ~/claude-telegram-upgrade
claude
```

Then say **"set it up"** — Claude Code reads the included `CLAUDE.md` and walks you through:
- Configuring your Telegram bot token
- Setting up multi-project isolation (optional)
- Launching tmux sessions
- Testing everything

## Architecture

```
Your Phone (Telegram)
    │
    ▼
Cloud Server (VPS)
    ├── tmux: claude (project-1)  ← Telegram bot 1
    ├── tmux: claude (project-2)  ← Telegram bot 2
    └── whisper-cpp (voice → text)
```

## Quick Reference

```bash
# Attach to a project session
TERM=xterm-256color tmux attach -t project-name

# Detach from tmux
Ctrl-b d

# List sessions
tmux list-sessions

# Launch Claude Code for a project
export CLAUDE_CODE_OAUTH_TOKEN=$(cat ~/.claude/.setup-token)
cd ~/projects/my-project
claude --channels plugin:telegram@claude-plugins-official \
       --dangerously-skip-permissions \
       --effort high --model opus
```

## Tailscale (optional)

Route all server traffic through your home IP:

```bash
# Install Tailscale on server
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --authkey=tskey-auth-xxxxx

# Set your home machine as exit node
sudo tailscale set --exit-node=<home-tailscale-ip>
```

Your home machine needs Tailscale with `--advertise-exit-node` enabled.

## What's Included

| Component | Purpose |
|-----------|---------|
| Claude Code | AI coding agent |
| Bun | JavaScript runtime (runs Telegram plugin) |
| whisper-cpp | Local speech-to-text for voice messages |
| ffmpeg | Audio conversion (.oga → .wav) |
| GitHub CLI | Git operations |
| tmux | Persistent terminal sessions |
| [telegram-upgrade](https://github.com/egerev/claude-telegram-upgrade) | Zombie fix + voice transcription patches |

## Troubleshooting

See [cloud-server-setup.md](https://github.com/egerev/claude-telegram-upgrade/blob/main/docs/cloud-server-setup.md) for detailed troubleshooting guide.

## License

MIT
