# OpenClaw Fully Autonomous Agent

A fully autonomous AI agent for OpenClaw that operates like a human. Browses the web, logs into platforms, creates accounts, manages files, runs scheduled tasks, and communicates across multiple channels — all without constant prompts.

## What It Does

Your agent operates 24/7:
1. **Browses the web** — navigates, clicks, types, fills forms, downloads files
2. **Logs into any platform** — reads credentials, handles 2FA automatically
3. **Creates new accounts** — signs up on websites, verifies email, sets up 2FA
4. **Controls your machine** — manages files, launches apps, takes screenshots
5. **Runs scheduled tasks** — heartbeat scheduler wakes agent at intervals
6. **Communicates** — Telegram, Discord, WhatsApp, Slack, Signal
7. **Creates content** — images, videos, music, voiceovers via platform UIs
8. **Publishes** — posts to Instagram, TikTok, YouTube, X, LinkedIn

**No API keys needed. Just your platform accounts.**

## Quick Install

### Linux / macOS / WSL / Git Bash

```bash
git clone https://github.com/Amenthyx/openclaw-content-engine.git
cd openclaw-content-engine
bash install.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/Amenthyx/openclaw-content-engine.git
cd openclaw-content-engine
powershell -ExecutionPolicy Bypass -File install.ps1
```

### What the installer does

The interactive installer walks you through:

1. **Detects** your OpenClaw installation (local, Docker, or custom path)
2. **Creates your agent** with custom name, emoji, and identity
3. **Deploys SOUL.md** — your agent's persistent personality, goals, and preferences
4. **Configures full autonomy:**
   - Browser control (lobster plugin + Playwright)
   - System access (filesystem, clipboard, processes, network)
   - Session persistence (cookies auto-saved between sessions)
   - Heartbeat scheduler (configurable interval for background tasks)
   - Multi-channel gateway (Telegram, Discord, WhatsApp, Slack, Signal)
5. **Installs tools:**
   - `totp.sh` — auto-generates 2FA codes from stored secrets
   - `pwgen.sh` — generates secure random passwords
   - `screenshot.sh` — captures desktop/window screenshots
   - Playwright Chromium, FFmpeg, ImageMagick, pyotp
6. **Deploys credentials template** (30+ platform slots)
7. **Indexes memory** (16 knowledge files)
8. **Restarts gateway** and verifies everything

### After install

1. **Edit credentials** — add your platform email/password:
   ```
   ~/.openclaw/credentials.json
   ```

2. **Customize SOUL.md** — set your goals, preferences, schedule:
   ```
   ~/.openclaw/workspace/SOUL.md
   ```

3. **Configure channel tokens:**
   ```bash
   openclaw config set channels.telegram.token YOUR_BOT_TOKEN
   ```

4. **Test the agent:**
   ```
   "Open the browser and go to google.com"
   "Create a new GitHub account"
   "Take a screenshot of my desktop"
   "What files are on my Desktop?"
   ```

## Architecture

```
openclaw-content-engine/
├── knowledge/                    # 16 knowledge files
│   ├── 00-system-identity.md     # Core identity & browser instructions
│   ├── 01-platform-authentication.md
│   ├── 02-image-generation.md
│   ├── 03-video-generation.md
│   ├── 04-audio-music.md
│   ├── 05-content-strategy.md
│   ├── 06-workflow-orchestration.md
│   ├── 07-prompt-engineering.md
│   ├── 08-asset-management.md
│   ├── 09-analytics-optimization.md
│   ├── 10-safety-compliance.md
│   ├── 11-browser-automation.md
│   ├── 12-api-endpoints-reference.md
│   ├── 13-autonomous-operations.md  # NEW: heartbeat, scheduling, proactive tasks
│   ├── 14-account-creation.md       # NEW: signup flows, email verification, 2FA
│   └── 15-system-control.md         # NEW: OS control, files, apps, processes
├── skills/
│   └── content-engine/
│       └── SKILL.md
├── IDENTITY.md                   # Agent identity (browser + system + autonomy)
├── SOUL.md                       # Agent personality, goals, schedule (template)
├── credentials-template.json     # 30+ platform login slots
├── install.sh                    # Installer (Linux/macOS/WSL/Git Bash)
├── install.ps1                   # Installer (Windows PowerShell)
└── README.md
```

## Supported Platforms

### Content Creation
| Platform | Used For | Login Method |
|----------|----------|-------------|
| ChatGPT | Image generation (DALL-E), writing | Email/password |
| ElevenLabs | Voiceovers, voice cloning | Email/password |
| Higgsfield | Avatar video (Soul + DoP + Speak) | Email/password |
| Suno AI | Music generation | Email/password |
| Runway ML | Cinematic video | Email/password |
| Midjourney | Artistic images (via Discord) | Discord login |
| Canva | Design templates | Email/password |
| Stability AI | SD3 images | Email/password |
| Kling AI | Video generation | Email/password |
| Pika | Video generation | Email/password |

### Publishing
Instagram, TikTok, YouTube, X/Twitter, LinkedIn, Reddit, Pinterest

### Communication
Telegram, Discord, WhatsApp, Slack, Signal

### Productivity
Google Workspace, GitHub, Notion, Dropbox

## How the Agent Works

### Browser Control
The agent uses OpenClaw's lobster plugin (Playwright-based browser):
```
browser open https://example.com    — Navigate to URL
browser snapshot                    — Read page (get element ref numbers)
browser click 12                    — Click element by ref
browser type 23 "hello"             — Type into field
browser fill --fields '[...]'       — Fill multiple fields
browser download 15 --save /path    — Download file
browser cookies                     — Save/restore sessions
```

### System Control
The agent uses the exec tool for OS-level operations:
```
exec ls -la ~/Desktop               — List files
exec ffmpeg -i in.mp4 out.mp4       — Process video
exec bash ~/.openclaw/workspace/totp.sh chatgpt   — Get 2FA code
exec bash ~/.openclaw/workspace/pwgen.sh 24        — Generate password
exec bash ~/.openclaw/workspace/screenshot.sh      — Take screenshot
```

### Account Creation
The agent can create accounts on new platforms:
1. Navigate to signup page
2. Generate secure password (`pwgen.sh`)
3. Fill registration form
4. Check email for verification (`email_primary` credentials)
5. Click verification link
6. Set up 2FA if available
7. Save credentials to `credentials.json`

### Heartbeat Scheduler
When enabled, the agent wakes at configured intervals to:
- Check inbox for new messages
- Run scheduled content posts
- Monitor active tasks
- Perform health checks
- Execute custom recurring jobs

## Security

- `credentials.json` is gitignored — never committed
- Sessions stored as cookies — credentials only read at login time
- TOTP secrets stored locally, codes generated on-demand
- Passwords generated with cryptographic randomness
- All data stays on your machine (local-first)

## Troubleshooting

**Agent can't browse**
```bash
openclaw config set plugins.entries.lobster.enabled true
openclaw config set tools.allow '["*"]'
openclaw config set agents.defaults.sandbox.mode off
openclaw gateway stop && openclaw gateway
```

**CAPTCHA appears** — Open `http://localhost:6080` and solve manually

**2FA code fails** — Check that `2fa_secret` in credentials.json is the base32 secret (not the QR URL)

**Heartbeat not firing** — Verify: `openclaw config get heartbeat.enabled`

**Node host disconnected**
```bash
openclaw devices list        # Find pending request
openclaw devices approve <id> # Approve it
openclaw nodes status         # Verify Connected: 1+
```

## License

MIT
