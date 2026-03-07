---
name: content-engine
description: Fully autonomous agent with browser control, account creation, system access, scheduled tasks, and multi-platform content creation. Operates like a human — logs into websites, creates accounts, manages files, and publishes content.
homepage: https://github.com/Amenthyx/openclaw-content-engine
metadata:
  {
    "openclaw":
      {
        "emoji": "🤖",
      },
  }
---

# Fully Autonomous Agent

Operates as a fully autonomous personal AI agent through OpenClaw's built-in tools. Browses the web, logs into platforms, creates new accounts, controls the machine, runs scheduled tasks, and creates/publishes content — all without API keys.

## How It Works

1. Reads SOUL.md for personality, goals, and schedule
2. Reads credentials.json for platform logins
3. Uses the browser tool to navigate and interact with any website
4. Uses the exec tool for system operations (files, apps, commands)
5. Runs heartbeat tasks at configured intervals
6. Communicates across Telegram, Discord, WhatsApp, Slack, Signal

## Core Capabilities

### Browser Automation
- Navigate any website, fill forms, click buttons, download files
- Log into platforms with email/password + auto 2FA
- Create new accounts (signup, email verification, 2FA setup)
- Session persistence via cookies (auto-saved between sessions)

### System Control
- File operations (create, read, move, copy, delete, search)
- Application launching and window management
- Screenshot capture (browser + desktop)
- Process management (start, stop, monitor)
- Package installation and system info

### Content Creation
- Image generation: ChatGPT (DALL-E), Midjourney, Canva, Stability AI
- Video generation: Higgsfield, Runway ML, Kling AI, Pika
- Audio/Music: ElevenLabs (TTS), Suno AI (music)
- Video editing: FFmpeg (assembly, transitions, subtitles)
- Social publishing: Instagram, TikTok, YouTube, X/Twitter, LinkedIn

### Autonomous Operations
- Heartbeat scheduler for recurring background tasks
- Proactive monitoring (inbox, tasks, errors)
- Self-healing with retry strategies
- Multi-step pipeline orchestration
- Decision framework (act vs ask based on risk level)

## Tools Used

- **browser** — Playwright browser (lobster plugin)
- **exec** — Shell command execution
- **file read/write** — Local file management
- **totp.sh** — 2FA code generation from stored secrets
- **pwgen.sh** — Secure password generation
- **screenshot.sh** — Desktop/window capture

## Required Config

```bash
openclaw config set tools.allow '["*"]'
openclaw config set agents.defaults.sandbox.mode off
openclaw config set plugins.entries.lobster.enabled true
openclaw node install && openclaw node restart
```

## Memory Knowledge Base

16 knowledge files covering:
- Browser automation and platform login flows
- Account creation and email verification
- System control and OS operations
- Autonomous operations and scheduling
- Image/video/audio generation workflows
- Content strategy and publishing
- Prompt engineering per platform
- Safety, compliance, and error recovery
