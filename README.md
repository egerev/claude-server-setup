# Claude Server Setup

Run Claude Code 24/7 on a cloud server with Telegram integration. Chat with your AI from your phone — text and voice messages, multiple projects, always on.

## What You Get

- **Always-on Claude Code** — runs in tmux, survives disconnects
- **Telegram integration** — chat from your phone via Telegram bots
- **Voice messages** — auto-transcribed locally via Whisper (no API keys)
- **Multi-project** — separate bot per project, fully isolated
- **Patched** — zombie process fix + async voice transcription from [claude-telegram-upgrade](https://github.com/egerev/claude-telegram-upgrade)

## How to Set Up

Just share this repo with Claude Code and let it handle everything.

```
You: Hey, I want to set up a cloud server for Claude Code with Telegram.
     Here's the guide: https://github.com/egerev/claude-server-setup

Claude: *reads the CLAUDE.md and walks you through the entire setup*
```

Claude Code will:
1. Help you get your auth token
2. Help you choose and set up a VPS (or use your existing one)
3. Install everything on the server via SSH
4. Configure Telegram bots
5. Clone your projects
6. Launch tmux sessions
7. Guide you through bot pairing
8. Test text and voice messages

You just answer questions and follow simple instructions when needed (like creating a bot in Telegram).

## Requirements

- Claude Code running on your local machine
- Claude subscription (Pro, Max, Team, or Enterprise)
- SSH access to a VPS (or Claude can help you set one up)
- Telegram account

Works on macOS and Linux. Windows users: use WSL2.

No incoming ports need to be opened — the bot uses outgoing HTTPS connections to Telegram's API.

## Architecture

```
Your Phone
    │ Telegram
    ▼
Cloud Server (Ubuntu VPS)
    ├── tmux: claude (project-1) ← Bot 1
    ├── tmux: claude (project-2) ← Bot 2
    └── whisper-cpp (voice → text, local)
```

## What Gets Installed

| Component | Purpose |
|-----------|---------|
| Claude Code | AI coding agent |
| Bun | Runs the Telegram plugin |
| whisper-cpp | Voice message transcription |
| ffmpeg | Audio format conversion |
| GitHub CLI | Repo management |
| tmux | Persistent sessions |

## License

MIT
