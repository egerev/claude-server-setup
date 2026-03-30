# Claude Server Setup — Auto-Configuration Guide

You are helping the user set up a cloud server for running Claude Code with Telegram integration. The bootstrap script has already installed Claude Code, Bun, Node.js, and GitHub CLI. Your job is to finish the setup.

## First Interaction

When the user says "set it up" or similar, explain what you're about to do:

---

I'll set up this server as a persistent Claude Code environment with Telegram integration. Here's what I'll do:

1. **Install dependencies** — ffmpeg (audio), whisper-cpp (voice transcription), cmake
2. **Set up Telegram plugin** — install the official plugin, apply patches (zombie process fix + voice transcription)
3. **Configure your Telegram bot** — you'll need a bot token from @BotFather
4. **Create project sessions** — tmux sessions for each project, each with its own bot
5. **Test everything** — verify text and voice messages work

The whole process takes about 5-10 minutes. I'll ask you a few questions along the way. Ready?

---

Wait for confirmation before proceeding.

## Step 1: Install Dependencies

```bash
sudo apt-get install -y -qq ffmpeg cmake build-essential
```

### Build whisper-cpp

```bash
cd /tmp
rm -rf whisper.cpp
git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
cmake -B build
cmake --build build --config Release -j$(nproc)
sudo cp build/bin/whisper-cli /usr/local/bin/whisper-cpp || sudo cp build/bin/main /usr/local/bin/whisper-cpp
sudo chmod +x /usr/local/bin/whisper-cpp
cd ~
```

### Download Whisper model

Ask the user: "Which Whisper model? `small` (466MB, good balance) or `medium` (1.5GB, better for non-English)?"

```bash
mkdir -p ~/.local/share/whisper-models
curl -L --progress-bar -o ~/.local/share/whisper-models/ggml-<MODEL>.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-<MODEL>.bin"
```

## Step 2: Set Up Telegram Plugin

### Enable plugin

Check `~/.claude/settings.json` has:
```json
{
  "enabledPlugins": {
    "telegram@claude-plugins-official": true
  }
}
```

### Download the plugin

Run Claude Code once to trigger plugin download:
```bash
source ~/.bashrc
claude -p "ok" --dangerously-skip-permissions 2>&1 || true
```

Wait a few seconds, then check:
```bash
find ~/.claude/plugins -name 'server.ts' -path '*/telegram/*' 2>/dev/null
```

If no results, the plugin may need a second attempt or manual clone:
```bash
cd /tmp
git clone --depth 1 https://github.com/anthropics/claude-plugins-official.git 2>/dev/null || true
MARKET_DIR="$HOME/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram"
if [ ! -f "$MARKET_DIR/server.ts" ]; then
  mkdir -p "$MARKET_DIR"
  cp -r /tmp/claude-plugins-official/external_plugins/telegram/* "$MARKET_DIR/"
  cd "$MARKET_DIR" && bun install --no-summary
fi
```

### Apply patches

Clone the upgrade repo and apply patches to ALL plugin locations:

```bash
cd ~
git clone https://github.com/egerev/claude-telegram-upgrade.git 2>/dev/null || true

PLUGIN_FILES=$(find ~/.claude/plugins -name 'server.ts' -path '*/telegram/*' 2>/dev/null)
for f in $PLUGIN_FILES; do
  DIR=$(dirname "$f")
  REPO_ROOT=$(echo "$DIR" | sed 's|/external_plugins/telegram||; s|/telegram/[0-9.]*||')
  cd "$REPO_ROOT"
  git apply ~/claude-telegram-upgrade/patches/all.patch 2>/dev/null && echo "Patched: $f" || echo "Already patched: $f"
done
```

Verify patches:
```bash
for f in $PLUGIN_FILES; do
  echo "$f: $(grep -c 'transcribeVoice\|killOldInstance' "$f") patch markers"
done
```

## Step 3: Configure Telegram Bot

Ask the user: "Send me your Telegram bot token from @BotFather. Format: `123456789:AAH...`"

If they don't have one, explain:
1. Open Telegram, search for @BotFather
2. Send `/newbot`, follow the prompts
3. Copy the token

For each bot token provided:

```bash
# Ask for a project name
PROJECT_NAME="<name>"

# Create channel directory
mkdir -p ~/.claude/channels/telegram-$PROJECT_NAME

# Save token
echo "TELEGRAM_BOT_TOKEN=<TOKEN>" > ~/.claude/channels/telegram-$PROJECT_NAME/.env
chmod 600 ~/.claude/channels/telegram-$PROJECT_NAME/.env
```

## Step 4: Set Up Projects

Ask: "What GitHub repos do you want to connect? Give me the URLs or `owner/repo` names."

For each repo:

```bash
mkdir -p ~/projects
cd ~/projects
gh repo clone <owner/repo> 2>/dev/null || git clone <url>
```

If `gh` is not authenticated:
```bash
# Ask user for a GitHub token or have them run:
gh auth login --with-token
```

Create per-project config:

```bash
WHISPER_MODEL_PATH=$(find ~/.local/share/whisper-models -name '*.bin' | head -1)

mkdir -p ~/projects/<repo>/.claude
cat > ~/projects/<repo>/.claude/settings.local.json << JSON
{
  "env": {
    "TELEGRAM_STATE_DIR": "/home/$(whoami)/.claude/channels/telegram-<PROJECT_NAME>",
    "TELEGRAM_WHISPER_MODEL": "$WHISPER_MODEL_PATH"
  }
}
JSON
```

## Step 5: Create tmux Sessions and Launch

For each project:

```bash
TOKEN=$(cat ~/.claude/.setup-token | tr -d '[:space:]')

tmux new-session -d -s <PROJECT_NAME> -c ~/projects/<repo>
tmux send-keys -t <PROJECT_NAME> "export PATH=\"\$HOME/.bun/bin:\$PATH\" CLAUDE_CODE_OAUTH_TOKEN=\"$TOKEN\" && claude --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions --effort high --model opus" Enter
```

**Important:** First launch needs interactive theme selection. Tell the user:
"You need to attach to each tmux session once and press Enter to select the theme. After that it runs headless."

```bash
TERM=xterm-256color tmux attach -t <PROJECT_NAME>
# Press Enter for theme
# Ctrl-b d to detach
```

## Step 6: Verify

After the user completes theme selection:

```bash
# Check bots are running
ps aux | grep "bun server.ts" | grep -v grep

# Check PID files (zombie fix working)
ls -la ~/.claude/channels/telegram-*/server.pid 2>/dev/null

# Check tmux sessions
tmux list-sessions
```

Tell the user: "Send a text message to your bot in Telegram. Then try a voice message."

## Step 7: Pairing

Each Telegram bot needs pairing. Tell the user:
1. Send any message to the bot in Telegram
2. The bot will reply with a pairing code
3. Attach to the tmux session: `TERM=xterm-256color tmux attach -t <name>`
4. Run: `/telegram:access pair <CODE>`

## Troubleshooting

### Plugin not found after claude -p
The plugin downloads asynchronously. Try running `claude -p "ok"` again, or manually clone as shown in Step 2.

### "Channels require claude.ai authentication"
The `CLAUDE_CODE_OAUTH_TOKEN` env var is not set. Run:
```bash
source ~/.bashrc
echo $CLAUDE_CODE_OAUTH_TOKEN | head -c 20
```
If empty, check `~/.claude/.setup-token` exists.

### "API Usage Billing" instead of subscription
`ANTHROPIC_API_KEY` is overriding OAuth. Remove it:
```bash
unset ANTHROPIC_API_KEY
sed -i '/ANTHROPIC_API_KEY/d' ~/.bashrc
```

### Voice messages not transcribed
Check whisper-cpp is installed and model exists:
```bash
which whisper-cpp
ls ~/.local/share/whisper-models/
```
Check `TELEGRAM_WHISPER_MODEL` in project settings points to correct path.

### tmux terminal error
Use: `TERM=xterm-256color tmux attach -t <name>`

## Important Notes

- NEVER display or log bot tokens — they are secrets
- `chmod 600` on all `.env` and `.setup-token` files
- Plugin updates may overwrite patches — re-apply after Claude Code updates
- One bot token = one consumer. Don't run the same bot on two machines.
