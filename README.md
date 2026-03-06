# OpenClaw Content Engine

Autonomous multi-platform content creation knowledge base for ClawBot. Transforms OpenClaw into a fully independent media manager that logs into platforms via browser — **no API keys needed** — and generates videos, images, music, voiceovers, and publishes across all major social platforms.

## How It Works

ClawBot operates like a human:
1. Opens Chromium browser inside the Docker container
2. Logs into each platform using your email/password
3. Creates content through the platform's UI (generate images, videos, music)
4. Downloads generated assets locally
5. Processes with FFmpeg (transitions, subtitles, music mixing)
6. Logs into social platforms and publishes the content
7. You can watch everything in real-time via noVNC at `http://localhost:6080`

**No API keys. No tokens. Just your existing platform accounts.**

## What's Inside

**13 knowledge files (6,000+ lines)** that get indexed into OpenClaw's memory:

| Domain | What It Covers |
|--------|---------------|
| **Platform Auth** | Browser login flows for 16 platforms, credential storage, session management, 2FA handling |
| **Image Generation** | ChatGPT browser (DALL-E), Higgsfield Soul, Midjourney (Discord), Stability AI, Canva |
| **Video Generation** | Higgsfield pipeline (Soul→DoP→Speak), Runway ML, Kling AI, Pika Labs, 20+ FFmpeg commands |
| **Audio & Music** | ElevenLabs browser TTS + voice cloning, Suno AI music, FFmpeg audio processing |
| **Content Strategy** | Platform specs, posting schedules, script frameworks, hashtag strategies, brand voice |
| **Workflow Orchestration** | 7 pipeline templates, error recovery, provider fallbacks, cost estimation |
| **Prompt Engineering** | Per-platform prompt patterns, 10 content-type templates, dynamic construction |
| **Asset Management** | File naming, folder structure, cloud storage (Dropbox/Drive via browser) |
| **Analytics** | Platform dashboard reading, KPIs, performance scoring, reporting templates |
| **Safety & Compliance** | Content policies per platform, AI disclosure, copyright, GDPR, accessibility |
| **Browser Automation** | Human-like behavior patterns, CAPTCHA handling, session persistence, Playwright code |
| **Platform Reference** | All platform URLs, UI navigation paths, subscription costs |

## Prerequisites

- **Docker** installed and running
- **ClawBot container** running (from [OpenClaw-Docker](https://github.com/Amenthyx/OpenClaw-Docker))
- **Platform accounts** (email/password) for the services you want to use

### Platform Accounts Needed

| Platform | Cost | Used For |
|----------|------|----------|
| ChatGPT Plus | $20/mo | Image generation (DALL-E), script writing, vision analysis |
| ElevenLabs | $5-22/mo | Voiceovers, voice cloning |
| Higgsfield | Free/Paid | Avatar video generation (Soul→DoP→Speak pipeline) |
| Suno AI | $10/mo | AI music generation |
| Runway ML | $15/mo | Cinematic video generation |
| Midjourney | $10/mo | Artistic image generation (via Discord) |
| Canva Pro | $13/mo | Design templates and branded content |
| Instagram | Free | Social media publishing |
| TikTok | Free | Social media publishing |
| YouTube | Free | Video publishing |
| X/Twitter | Free | Social media publishing |
| LinkedIn | Free | Professional content publishing |
| Dropbox | Free/Paid | Cloud asset storage |
| Google | Free | YouTube, Google Drive, Gemini |

You only need accounts for the platforms you want to use. The system works with any combination.

## Installation

### Step 1: Clone and Install

```bash
git clone https://github.com/Amenthyx/openclaw-content-engine.git
cd openclaw-content-engine
bash install-to-clawbot.sh
```

This will:
1. Copy 13 knowledge files into ClawBot's memory
2. Install the `content-engine` skill
3. Deploy agent instructions for browser-based operation
4. Create `credentials.json` template inside the container
5. Set up sessions and workspace directories
6. Trigger memory reindex

### Step 2: Add Your Login Credentials

```bash
docker exec -it clawbot nano /home/node/.openclaw/credentials.json
```

Fill in your email and password for each platform you want to use:

```json
{
  "chatgpt": {
    "email": "your@email.com",
    "password": "your-password",
    "2fa_secret": ""
  },
  "higgsfield": {
    "email": "your@email.com",
    "password": "your-password",
    "2fa_secret": ""
  },
  "elevenlabs": {
    "email": "your@email.com",
    "password": "your-password",
    "2fa_secret": ""
  }
}
```

**2FA**: If you have 2FA enabled, add the TOTP secret (the long base32 string shown when setting up 2FA) to `2fa_secret`. ClawBot will generate codes automatically. If left empty and 2FA triggers, ClawBot will pause and ask you to solve it via VNC.

### Step 3: Start Using It

Send ClawBot a message through any connected channel (Telegram, Discord, etc.):

```
Create a 30-second promo video for my coffee brand "BeanCraft"
```

### Step 4: Watch It Work

Open your browser and go to:
```
http://localhost:6080
```

You'll see ClawBot's browser in real-time — logging into platforms, generating content, downloading files, and publishing.

## Usage Examples

**Product promo video:**
```
Create a 30-second promo video for my fitness app.
Style: energetic, modern. Platforms: Instagram Reels + TikTok.
```

**Social media images:**
```
Create 5 Instagram carousel images about AI trends in 2026.
Brand colors: #FF6B35, #004E89. Style: clean, minimalist.
```

**Full content package:**
```
Plan a week of content for a skincare brand.
Platforms: Instagram, TikTok, YouTube Shorts.
Include: images, short videos, captions, and hashtags.
```

**Music and voiceover:**
```
Create a 30-second upbeat background track and record a voiceover:
"Welcome to BeanCraft — where every cup tells a story."
```

**Publish content:**
```
Upload the latest video to Instagram Reels and TikTok
with optimized captions and hashtags.
```

## Architecture

```
User Message → ClawBot Agent
                    ↓
            Search memory (knowledge base)
                    ↓
            Load credentials from credentials.json
                    ↓
            Open Chromium browser (Xvfb display)
                    ↓
            Login to platform (restore cookies or fresh login)
                    ↓
            Create content (type prompts, upload files, click generate)
                    ↓
            Download generated assets to workspace/
                    ↓
            Process with FFmpeg (merge, transitions, subtitles)
                    ↓
            Login to social platforms → publish
                    ↓
            Report results to user
```

## Project Structure

```
openclaw-content-engine/
├── .ai/
│   └── context_base.md              # AI agent context
├── knowledge/                        # Knowledge base (13 files)
│   ├── 00-system-identity.md         # Agent identity & decision framework
│   ├── 01-platform-authentication.md # Browser login flows & credentials
│   ├── 02-image-generation.md        # Image creation via browser
│   ├── 03-video-generation.md        # Video generation & FFmpeg
│   ├── 04-audio-music.md             # Audio, TTS, music via browser
│   ├── 05-content-strategy.md        # Content planning & optimization
│   ├── 06-workflow-orchestration.md   # Pipeline templates & error recovery
│   ├── 07-prompt-engineering.md       # Platform-specific prompt patterns
│   ├── 08-asset-management.md         # File organization & storage
│   ├── 09-analytics-optimization.md   # Performance tracking & reporting
│   ├── 10-safety-compliance.md        # Content policies & legal
│   ├── 11-browser-automation.md       # Browser patterns & CAPTCHA handling
│   └── 12-api-endpoints-reference.md  # Platform URLs & browser workflows
├── skills/
│   └── content-engine/
│       └── SKILL.md                  # OpenClaw skill definition
├── credentials-template.json         # Template for platform logins
├── install-to-clawbot.sh             # One-command ClawBot installer
├── deploy.sh                         # Generic deploy script
└── README.md
```

## Updating

```bash
cd openclaw-content-engine
git pull
bash install-to-clawbot.sh
```

The installer is idempotent and won't overwrite your `credentials.json`.

## Troubleshooting

**"Container 'clawbot' is not running"**
```bash
cd /path/to/OpenClaw-Docker
docker compose up -d
```

**CAPTCHA appears during automation**
Open `http://localhost:6080` in your browser, solve the CAPTCHA manually, then ClawBot will continue automatically.

**Login keeps failing**
- Verify credentials in `credentials.json` are correct
- Some platforms block login from server IPs — try using the VNC to login manually once
- If 2FA is enabled, add the TOTP secret to `2fa_secret`

**Memory search returns no results**
```bash
docker exec -u node clawbot openclaw memory sync --force
```

**Browser crashes or freezes**
```bash
docker restart clawbot
```

**Can't see the browser via VNC**
- Check that ports 6080 (noVNC) and 5900 (VNC) are exposed in docker-compose.yml
- Try direct VNC at `vnc://localhost:5900`

## Security Notes

- `credentials.json` lives inside the Docker volume — never committed to git
- File permissions are set to `600` (owner-only read/write)
- Sessions are stored as cookies in the container — no credentials cached in memory
- VNC access should be password-protected in production (`VNC_PASSWORD` env var)
- Consider running behind a firewall — don't expose ports 6080/5900 to the internet

## License

MIT
