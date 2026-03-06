---
name: content-engine
description: Autonomous multi-platform content creation engine. Logs into platforms via browser (no API keys) to generate videos, images, music, and publish to social media.
homepage: https://github.com/Amenthyx/openclaw-content-engine
metadata:
  {
    "openclaw":
      {
        "emoji": "🎬",
        "requires": { "bins": ["chromium", "ffmpeg"] },
      },
  }
---

# Content Engine

Autonomous multi-platform content creation system that operates entirely through **browser automation** — no API keys needed. Logs into platforms like a human user, generates professional content, and publishes across social media.

## How It Works

ClawBot logs into each platform using email/password credentials stored in `credentials.json`, performs all actions through the browser (Chromium on Xvfb), and uses FFmpeg locally for video/audio processing.

## Capabilities

- **Image Generation**: ChatGPT (DALL-E via browser), Higgsfield Soul, Midjourney (Discord), Stability AI, Canva
- **Video Generation**: Higgsfield (Soul→DoP→Speak), Runway ML, Kling AI, Pika Labs
- **Audio/Music**: ElevenLabs (browser TTS + voice cloning), Suno AI (browser music gen)
- **Video Editing**: FFmpeg local assembly, transitions, subtitles, color grading
- **Social Publishing**: Instagram, TikTok, YouTube, X/Twitter, LinkedIn — all via browser login
- **Content Strategy**: Calendar management, script writing, platform optimization

## Setup

### 1. Install the knowledge base
```bash
bash install-to-clawbot.sh
```

### 2. Configure credentials
```bash
# Copy the template into ClawBot's volume
docker cp credentials-template.json clawbot:/home/node/.openclaw/credentials.json

# Edit with your login details
docker exec -it clawbot nano /home/node/.openclaw/credentials.json
```

### 3. Start using it
Send ClawBot a message:
```
Create a 30-second promo video for my coffee brand.
Style: warm, artisan. Platforms: Instagram Reels + TikTok.
```

## Monitoring

Watch ClawBot work in real-time via noVNC:
```
http://localhost:6080
```

## Platform Accounts Needed

| Platform | Subscription | Used For |
|----------|-------------|----------|
| ChatGPT Plus/Pro | $20-200/mo | Images (DALL-E), scripts, vision |
| ElevenLabs | $5-22/mo | Voiceovers, voice cloning |
| Higgsfield | Free/Paid | Avatar video pipeline |
| Suno AI | $10/mo | Background music |
| Runway ML | $15/mo | Cinematic video |
| Midjourney | $10/mo | Artistic images |
| Canva Pro | $13/mo | Design templates |
| Instagram | Free | Social publishing |
| TikTok | Free | Social publishing |
| YouTube | Free | Social publishing |
| X/Twitter | Free | Social publishing |
| LinkedIn | Free | Social publishing |

## Memory Integration

Knowledge base stored in OpenClaw's memory at `memory/content-engine/`:
- 13 knowledge files covering auth, generation, strategy, pipelines, safety
- Automatically searched when handling content creation requests
- No API keys in any file — everything is browser-based
