# Claude Server Setup

You are guiding the user through setting up a cloud server for running Claude Code with Telegram integration. The user may have zero technical knowledge — explain everything simply, tell them exactly what to do, and do as much as possible yourself.

## When the user shares this repo or asks to set up

Start by explaining the end result:

---

This will set up a cloud server where Claude Code runs 24/7 with Telegram. You'll be able to:
- Chat with Claude from your phone via Telegram (text and voice messages)
- Have separate bots for different projects
- Voice messages are automatically transcribed — no API keys, runs locally on the server

Here's what we'll do together:
1. Get your Claude auth token (so the server can use your subscription)
2. Get a server (if you don't have one already)
3. I'll install everything on the server via SSH
4. Set up your Telegram bot(s)
5. Test it all

Let's start! Do you already have a VPS/cloud server, or do we need to set one up?

---

## Phase 1: Auth Token

Tell the user:

"First, I need your Claude Code auth token. Open a new terminal tab and run:"

```
claude setup-token
```

"This will open your browser — sign in, and it'll save a token. Then run:"

```
cat ~/.claude/.setup-token
```

"Paste the token here."

**Important:** Store the token in a variable. NEVER display it back to the user or include it in any output visible to others.

## Phase 2: Server

### If the user already has a server

Ask: "What's the SSH command to connect? Something like `ssh user@1.2.3.4` or `ssh -i key.pem user@ip`"

Test the connection:
```bash
ssh <their-command> "uname -a && echo 'SSH works'"
```

### If they need a server

Ask: "Which cloud provider do you have an account with? AWS, DigitalOcean, Vultr, Hetzner, or something else?"

Help them create a server:
- **AWS Lightsail**: Check `aws sts get-caller-identity`, then create via `aws lightsail create-instances`
- **DigitalOcean**: Check `doctl auth list`, then create via `doctl compute droplet create`
- **Other**: Guide them through their provider's dashboard

Recommended specs: Ubuntu 22.04+, 4GB RAM, 2 CPU, any region close to them.

After server is created, get the IP and set up SSH access.

## Phase 3: Install Everything

Run these commands on the server via SSH. Execute them yourself — don't ask the user to copy-paste.

### 3.1 System packages
```bash
ssh <server> "sudo apt-get update -qq && sudo apt-get install -y -qq git curl tmux ffmpeg jq cmake build-essential"
```

### 3.2 Node.js + Bun
```bash
ssh <server> "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - > /dev/null 2>&1 && sudo apt-get install -y -qq nodejs"
ssh <server> 'curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1'
```

### 3.3 Claude Code + GitHub CLI
```bash
ssh <server> "sudo npm install -g @anthropic-ai/claude-code > /dev/null 2>&1"
ssh <server> 'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null 2>&1 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && sudo apt-get update -qq && sudo apt-get install -y -qq gh'
```

### 3.4 Save auth token
```bash
ssh <server> "mkdir -p ~/.claude && echo -n '<TOKEN>' > ~/.claude/.setup-token && chmod 600 ~/.claude/.setup-token"
```

### 3.5 Environment config
```bash
ssh <server> 'grep -q "BUN_INSTALL" ~/.bashrc || cat >> ~/.bashrc << '\''BASHRC'\''

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
BASHRC'
```

Store the token in a dedicated env file (not in .bashrc):
```bash
ssh <server> 'mkdir -p ~/.claude && echo "export CLAUDE_CODE_OAUTH_TOKEN=$(cat ~/.claude/.setup-token | tr -d '"'"'[:space:]'"'"')" > ~/.claude/.env && chmod 600 ~/.claude/.env'
```

### 3.5a GitHub CLI authentication

Check if GitHub CLI is authenticated:
```bash
ssh <server> "gh auth status 2>&1 || echo 'NOT AUTHENTICATED'"
```

If not authenticated, guide the user to run device auth on the server:
```bash
ssh <server> "gh auth login --web"
```

Or, if they have a GitHub token, use:
```bash
ssh <server> "echo '<GITHUB_TOKEN>' | gh auth login --with-token"
```

### 3.6 Claude Code settings
```bash
ssh <server> 'cat > ~/.claude/settings.json << '\''JSON'\''
{
  "enabledPlugins": {
    "telegram@claude-plugins-official": true
  },
  "skipDangerousModePermissionPrompt": true
}
JSON'
```

### 3.7 Superflow skill (optional)

Ask: "Would you also like to install Superflow for project management workflows? (optional)"

Only install if the user says yes:
```bash
ssh <server> 'mkdir -p ~/.claude/commands && cd ~/.claude/commands && git clone https://github.com/egerev/superflow.git 2>/dev/null || true'
```

### 3.8 Whisper-cpp (voice transcription)

Ask: "Which Whisper model? `small` (466MB, good balance) or `medium` (1.5GB, better for non-English like Russian)?"

```bash
ssh <server> 'bash -s' << 'WHISPER'
cd /tmp && rm -rf whisper.cpp
git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp && cmake -B build && cmake --build build --config Release -j$(nproc)
sudo cp build/bin/whisper-cli /usr/local/bin/whisper-cpp 2>/dev/null || sudo cp build/bin/main /usr/local/bin/whisper-cpp
sudo chmod +x /usr/local/bin/whisper-cpp
mkdir -p ~/.local/share/whisper-models
curl -L --progress-bar -o ~/.local/share/whisper-models/ggml-<MODEL>.bin "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-<MODEL>.bin"
WHISPER
```

### 3.9 Telegram plugin + patches
```bash
ssh <server> 'bash -s' << 'TELEGRAM'
export PATH="$HOME/.bun/bin:$PATH"
export CLAUDE_CODE_OAUTH_TOKEN=$(cat ~/.claude/.setup-token | tr -d '[:space:]')

# Download plugin
claude -p "ok" --dangerously-skip-permissions 2>&1 || true
sleep 5

# Also manually ensure plugin exists
cd /tmp
git clone --depth 1 https://github.com/anthropics/claude-plugins-official.git 2>/dev/null || true
MARKET_DIR="$HOME/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram"
if [ ! -f "$MARKET_DIR/server.ts" ]; then
  mkdir -p "$MARKET_DIR"
  cp -r /tmp/claude-plugins-official/external_plugins/telegram/* "$MARKET_DIR/"
  cd "$MARKET_DIR" && bun install --no-summary
fi

# Clone patches and apply
cd ~
git clone https://github.com/egerev/claude-telegram-upgrade.git 2>/dev/null || true
for f in $(find ~/.claude/plugins -name 'server.ts' -path '*/telegram/*' 2>/dev/null); do
  DIR=$(dirname "$f")
  REPO_ROOT=$(echo "$DIR" | sed 's|/external_plugins/telegram||; s|/telegram/[0-9.]*||')
  cd "$REPO_ROOT"
  git apply ~/claude-telegram-upgrade/patches/all.patch 2>/dev/null && echo "Patched: $f" || echo "Skipped: $f"
done
TELEGRAM
```

Tell the user: "Base installation complete. Now let's set up your Telegram bot."

> **Note:** Most steps in Phase 3 are idempotent — if your SSH connection drops at any point, it's safe to re-run the commands from where you left off.

## Phase 4: Telegram Bot Setup

Ask: "Do you already have a Telegram bot token, or do we need to create one?"

If they need to create one, walk them through step by step:

---

Let's create a Telegram bot. It takes about 1 minute:

1. Open **Telegram** on your phone or desktop
2. Search for **@BotFather** (it has a blue checkmark)
3. Tap **Start** (or send `/start`)
4. Send: `/newbot`
5. BotFather will ask for a **name** — this is what users see (e.g., "My Claude Assistant")
6. Then it asks for a **username** — must end in `bot` (e.g., `my_claude_bot`)
7. BotFather will reply with your **token** — it looks like `123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw`

Copy that token and paste it here. Don't share it publicly — anyone with this token can control your bot.

---

If they want multiple projects with separate bots, tell them: "You can repeat this process to create additional bots — one per project. Each gets its own token."

After receiving the token:

Ask: "What should I call this project? (e.g., `myproject`, `work`, `personal`)"

```bash
ssh <server> "mkdir -p ~/.claude/channels/telegram-<PROJECT_NAME> && echo 'TELEGRAM_BOT_TOKEN=<TOKEN>' > ~/.claude/channels/telegram-<PROJECT_NAME>/.env && chmod 600 ~/.claude/channels/telegram-<PROJECT_NAME>/.env"
```

Ask: "Do you have a GitHub repo for this project? If yes, give me the URL or `owner/repo`."

```bash
ssh <server> 'bash -s' << 'PROJECT'
export PATH="$HOME/.bun/bin:$PATH"
mkdir -p ~/projects
cd ~/projects
gh repo clone <OWNER/REPO> 2>/dev/null || git clone <URL>

WHISPER_MODEL=$(find ~/.local/share/whisper-models -name '*.bin' | head -1)
mkdir -p ~/projects/<REPO>/.claude
cat > ~/projects/<REPO>/.claude/settings.local.json << JSON
{
  "env": {
    "TELEGRAM_STATE_DIR": "/home/$(whoami)/.claude/channels/telegram-<PROJECT_NAME>",
    "TELEGRAM_WHISPER_MODEL": "$WHISPER_MODEL"
  }
}
JSON
PROJECT
```

Add Telegram communication guidelines to the project's CLAUDE.md so Claude sends progress updates instead of going silent:

```bash
ssh <server> 'cat >> ~/projects/<REPO>/CLAUDE.md << '\''MD'\''

## Telegram Communication

This is a Telegram session. The user is on their phone and CANNOT see your terminal. They only see messages you explicitly send via the reply tool. Everything else — your thinking, tool calls, file reads, command output — is invisible to them.

**You are their only window into what is happening. Act accordingly:**

- When you start working, say what you are about to do: "Reading the config file..."
- Send progress updates every 20-30 seconds while working
- When running commands (tests, builds), tell the user and share the result
- Keep messages short — the user is on a phone screen
- Summarize file contents and command output instead of dumping raw text
- When done, clearly state what changed: "Fixed the bug in line 42, pushed to main"
- If something fails, explain what happened and what you will try next
- Voice messages arrive as `[voice]: transcribed text`
- The user can send CLI commands: /compact, /clear, /model, /effort
MD'
```

Ask: "Want to add another project with a different bot? Or is one enough for now?"

Repeat Phase 4 for each additional project.

## Phase 5: Launch

Ask: "Which Claude model do you want to use? Options: `opus` (most capable, requires Max plan), `sonnet` (fast, works with Pro plan). Default: sonnet"

If they choose opus, add `--model opus` to the launch command. If sonnet (or they don't know), use `--model sonnet`. Default to sonnet.

### Install claude-status-line (for /dash command)

```bash
ssh <server> 'bash -s' << 'STATUSLINE'
cd ~
git clone https://github.com/egerev/claude-status-line.git 2>/dev/null || true
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR/status_lines" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/data/sessions"
cp ~/claude-status-line/status_line.py "$CLAUDE_DIR/status_lines/status_line.py"
cp ~/claude-status-line/hook_prompt_submit.py "$CLAUDE_DIR/hooks/hook_prompt_submit.py"

# Patch status_line.py to dump data for /dash
python3 -c "
p = '$CLAUDE_DIR/status_lines/status_line.py'
c = open(p).read()
old = 'data = json.loads(sys.stdin.read())'
new = '''data = json.loads(sys.stdin.read())
        try:
            dp = Path.home() / \".claude\" / \"data\" / \"last_status.json\"
            dp.parent.mkdir(parents=True, exist_ok=True)
            dp.write_text(json.dumps(data, ensure_ascii=False))
        except Exception:
            pass'''
open(p, 'w').write(c.replace(old, new, 1))
"

# Update settings.json
python3 -c "
import json
p = '$CLAUDE_DIR/settings.json'
s = json.loads(open(p).read())
s['statusLine'] = {'type': 'command', 'command': 'python3 $CLAUDE_DIR/status_lines/status_line.py', 'padding': 0}
h = s.setdefault('hooks', {}).setdefault('UserPromptSubmit', [])
if not any('hook_prompt_submit' in hh.get('command','') for b in h for hh in b.get('hooks',[])):
    h.append({'hooks': [{'type': 'command', 'command': 'python3 $CLAUDE_DIR/hooks/hook_prompt_submit.py'}]})
open(p, 'w').write(json.dumps(s, indent=2))
"
echo "Status line installed"
STATUSLINE
```

### Create auto-restart wrapper

```bash
ssh <server> 'cat > ~/start-claude.sh << '\''SCRIPT'\''
#!/bin/bash
source ~/.claude/.env 2>/dev/null
export PATH="$HOME/.bun/bin:$PATH"

while true; do
  claude --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions --effort high --model ${1:-sonnet}
  echo "Claude Code exited. Restarting in 5 seconds..."
  sleep 5
done
SCRIPT
chmod +x ~/start-claude.sh'
```

### Launch sessions

For each project:

```bash
ssh <server> 'bash -s' << 'LAUNCH'
export PATH="$HOME/.bun/bin:$PATH"

tmux new-session -d -s <PROJECT_NAME> -c ~/projects/<REPO>
tmux send-keys -t <PROJECT_NAME> "~/start-claude.sh <MODEL>" Enter
LAUNCH
```

Tell the user:

"Almost done! The first time Claude Code starts, it asks you to pick a theme. You need to SSH into the server once and press Enter in each session. Run this in your terminal:"

```
ssh <server>
TERM=xterm-256color tmux attach -t <PROJECT_NAME>
```

"Press Enter to pick the theme, then Ctrl-b d to detach. Do this for each project."

## Phase 6: Pairing

After the user completes theme selection, tell them:

"Now send any message to your bot in Telegram (e.g., 'hi'). **The bot will reply directly in Telegram** with a pairing code — 5 lowercase letters, like `abcde`.

Then attach to the tmux session:
```
ssh <server>
TERM=xterm-256color tmux attach -t <PROJECT_NAME>
```

At the `>` prompt inside Claude Code, type:
```
/telegram:access pair <CODE>
```

Replace `<CODE>` with the 5-letter code the bot sent you in Telegram. Press Enter. Claude will confirm the pairing. Then Ctrl-b d to detach."

## Phase 7: Test

```bash
ssh <server> 'ps aux | grep "bun server" | grep -v grep'
```

Tell the user: "Everything is running. Try sending a text message, then a voice message to your bot in Telegram."

If they confirm it works: "You're all set! The server runs 24/7 — you can close your laptop and keep chatting via Telegram."

## Phase 8: Reboot Recovery (optional but recommended)

Create a restart script so sessions survive server reboots:

```bash
ssh <server> 'cat > ~/restart-claude.sh << '\''SCRIPT'\''
#!/bin/bash
source ~/.claude/.env
export PATH="$HOME/.bun/bin:$PATH"

for dir in ~/projects/*/; do
  PROJECT=$(basename "$dir")
  SETTINGS="$dir/.claude/settings.local.json"
  [ -f "$SETTINGS" ] || continue

  tmux has-session -t "$PROJECT" 2>/dev/null && continue

  tmux new-session -d -s "$PROJECT" -c "$dir"
  tmux send-keys -t "$PROJECT" "source ~/.claude/.env && export PATH=\"\$HOME/.bun/bin:\$PATH\" && claude --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions --effort high --model sonnet" Enter
  echo "Started: $PROJECT"
done
SCRIPT
chmod +x ~/restart-claude.sh'
```

Add to crontab:
```bash
ssh <server> '(crontab -l 2>/dev/null; echo "@reboot sleep 30 && /home/$(whoami)/restart-claude.sh >> /home/$(whoami)/claude-restart.log 2>&1") | crontab -'
```

Tell the user: "I've set up auto-restart. If the server reboots, Claude Code sessions will restart automatically after 30 seconds."

## Quick Reference (show at the end)

```
# Connect to server
ssh <server-command>

# Attach to project session
TERM=xterm-256color tmux attach -t <project>

# Detach
Ctrl-b d

# List sessions
tmux list-sessions

# Restart a session
tmux send-keys -t <project> C-c
# then re-run the claude command
```

## Important

- NEVER display or log bot tokens or OAuth tokens
- `chmod 600` on all secret files
- One bot token = one consumer — don't run the same bot on two machines
- Plugin updates may overwrite patches — re-apply from ~/claude-telegram-upgrade after updates
