# OpenClaw Content Engine

Autonomous multi-platform content creation for ClawBot. Logs into platforms via browser — **no API keys** — generates images, videos, music, voiceovers, and publishes to social media.

## How It Works

ClawBot operates like a human:
1. Opens Chromium browser (built into OpenClaw via the lobster plugin)
2. Logs into each platform using your email/password
3. Creates content through the platform's UI
4. Downloads generated assets locally
5. Processes with FFmpeg if needed
6. Publishes to social media
7. Watch it work in real-time via noVNC at `http://localhost:6080`

**No API keys. No tokens. Just your platform accounts.**

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

1. Detects your OpenClaw installation (local, Docker, or custom path)
2. Copies 13 knowledge files into ClawBot's memory
3. Installs the `content-engine` skill
4. **Configures ALL plugins and settings for full autonomy:**
   - `lobster` plugin — gives the agent browser control (navigate, click, type, screenshot, download)
   - `llm-task` plugin — enables background task execution
   - `tools.allow = ["*"]` — full tool access
   - `tools.elevated = true` — elevated actions from Telegram
   - `sandbox.mode = off` — browser and filesystem access
   - `exec.timeout = 1800s` — 30-minute timeout for long tasks
   - `maxConcurrent = 4` agents, `subagents = 8` — parallel execution
   - Workspace directory configured for your OS
5. Creates `credentials.json` template
6. Indexes memory
7. Verifies everything

### After install

1. **Edit credentials** — add your platform email/password:

   ```bash
   # Find and edit:
   ~/.openclaw/credentials.json
   ```

2. **Restart the gateway** (required to apply plugin changes):

   ```bash
   openclaw gateway stop
   openclaw gateway
   ```

3. **Test it** — send via Telegram:

   ```
   Open the browser and go to chat.openai.com
   ```

## Supported Platforms

| Platform | Used For | Cost |
|----------|----------|------|
| ChatGPT | Image generation (DALL-E), script writing | $20/mo |
| ElevenLabs | Voiceovers, voice cloning | $5-22/mo |
| Higgsfield | Avatar video (Soul + DoP + Speak) | Free/Paid |
| Suno AI | Music generation | $10/mo |
| Runway ML | Cinematic video | $15/mo |
| Midjourney | Artistic images (via Discord) | $10/mo |
| Canva | Design templates | $13/mo |
| Stability AI | SD3 images | Pay-per-use |
| Kling AI | Video generation | Free/Paid |
| Pika | Video generation | Free/Paid |
| Instagram | Publishing | Free |
| TikTok | Publishing | Free |
| YouTube | Publishing | Free |
| X/Twitter | Publishing | Free |
| LinkedIn | Publishing | Free |

You only need accounts for the platforms you want to use.

## Usage Examples

**Image generation:**
```
Create a product promo image for my coffee brand. Modern, warm colors.
```

**Video creation:**
```
Create a 30-second promo video for my fitness app.
Style: energetic, modern. Platforms: Instagram Reels + TikTok.
```

**Social media package:**
```
Plan a week of content for a skincare brand.
Platforms: Instagram, TikTok, YouTube Shorts.
```

**Music + voiceover:**
```
Create a 30-second upbeat background track and record a voiceover:
"Welcome to BeanCraft — where every cup tells a story."
```

**Publish:**
```
Upload the latest video to Instagram Reels and TikTok with optimized captions.
```

## Project Structure

```
openclaw-content-engine/
├── knowledge/                    # 13 knowledge files (6,000+ lines)
│   ├── 00-system-identity.md
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
│   └── 12-api-endpoints-reference.md
├── skills/
│   └── content-engine/
│       └── SKILL.md              # Skill definition
├── credentials-template.json     # Template for platform logins
├── install.sh                    # Installer (Linux/macOS/WSL/Git Bash)
├── install.ps1                   # Installer (Windows PowerShell)
└── README.md
```

## How the Browser Works

OpenClaw's lobster plugin provides a full Playwright-based browser. The agent controls it with commands like:

```
browser navigate https://chat.openai.com    — Go to URL
browser snapshot                             — Read page (get element refs)
browser click 12                             — Click element ref 12
browser type 23 "hello"                      — Type into element
browser download 15 --save /path/file.png    — Download file
browser cookies                              — Read/save session cookies
browser screenshot                           — Capture screenshot
```

The agent takes a snapshot, reads the page, finds interactive elements by their ref numbers, and interacts with them — exactly like a human would.

## Troubleshooting

**"I cannot access ChatGPT or generate images"**
The lobster plugin isn't enabled or gateway wasn't restarted. Run:
```bash
openclaw config set plugins.entries.lobster.enabled true
openclaw config set tools.allow '["*"]'
openclaw config set agents.defaults.sandbox.mode off
openclaw gateway stop && openclaw gateway
```

**CAPTCHA appears**
Open `http://localhost:6080` and solve it manually. ClawBot resumes automatically.

**Login fails**
- Check credentials in `~/.openclaw/credentials.json`
- Some platforms block server IPs — login manually once via VNC
- Add TOTP secret to `2fa_secret` if 2FA is enabled

**Memory search returns nothing**
```bash
openclaw memory index --force
```

**Browser crashes**
```bash
openclaw browser stop
openclaw browser start
```

**Gateway not running**
```bash
openclaw gateway status
openclaw gateway
```

## Updating

```bash
cd openclaw-content-engine
git pull
bash install.sh    # or: powershell -ExecutionPolicy Bypass -File install.ps1
```

The installer won't overwrite your `credentials.json`.

## Security

- `credentials.json` is gitignored — never committed
- Sessions stored as cookies — credentials only read at login time
- VNC should be password-protected in production
- Don't expose ports 6080/5900 to the internet

## License

MIT
