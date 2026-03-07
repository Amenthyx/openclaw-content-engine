# OpenClaw Fully Autonomous Agent

## What is this?
A complete setup that transforms OpenClaw into a fully autonomous AI agent. Operates like a human — browses the web, logs into platforms, creates new accounts, controls the machine, runs scheduled background tasks, and communicates across multiple channels. No API keys needed.

## Architecture
- **16 markdown knowledge files** organized by domain (content + autonomous ops + system control)
- **SOUL.md** — persistent agent personality, goals, schedule
- **IDENTITY.md** — agent capabilities and behavioral instructions
- Browser automation via **Playwright** (lobster plugin)
- System control via **exec** tool (files, apps, processes, network)
- **Heartbeat scheduler** for recurring background tasks
- **Multi-channel gateway** (Telegram, Discord, WhatsApp, Slack, Signal)
- **Session persistence** — cookies auto-saved between sessions
- **2FA auto-handling** — TOTP codes generated from stored secrets
- Credentials stored in `credentials.json` (30+ platform slots)

## Key Capabilities
- Browse any website, log in, interact with UIs
- Create new accounts (signup, email verification, 2FA setup)
- Control the machine (files, apps, clipboard, screenshots)
- Generate content (images, videos, music, voiceovers)
- Publish to social media
- Run scheduled tasks via heartbeat
- Communicate across messaging platforms

## Installation
```bash
bash install.sh          # Linux/macOS/WSL/Git Bash
# or
powershell -ExecutionPolicy Bypass -File install.ps1  # Windows
```
