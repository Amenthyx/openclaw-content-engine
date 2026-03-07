---
name: content-engine
description: Autonomous multi-platform content creation engine. Logs into platforms via browser (no API keys) to generate videos, images, music, and publish to social media.
homepage: https://github.com/Amenthyx/openclaw-content-engine
metadata:
  {
    "openclaw":
      {
        "emoji": "🎬",
      },
  }
---

# Content Engine

Autonomous multi-platform content creation system that operates through OpenClaw's **built-in browser tool** — no API keys needed. Logs into platforms with your credentials, creates content through the UI, and publishes to social media.

## How It Works

1. You send ClawBot a content request (via Telegram, Discord, etc.)
2. ClawBot searches its memory for relevant knowledge (platform workflows, prompts, specs)
3. ClawBot opens the browser, logs into the needed platform
4. Creates content through the browser UI (images, videos, music, voiceovers)
5. Downloads assets locally, processes with FFmpeg if needed
6. Logs into social platforms and publishes

All browser interactions use OpenClaw's built-in `browser` tool:
```
browser navigate https://chat.openai.com
browser snapshot
browser type [ref] "Generate an image: sunset over mountains"
browser press Enter
```

## Capabilities

- **Image Generation**: ChatGPT (DALL-E via browser), Higgsfield Soul, Midjourney (Discord), Canva
- **Video Generation**: Higgsfield (Soul→DoP→Speak), Runway ML, Kling AI, Pika
- **Audio/Music**: ElevenLabs (browser TTS), Suno AI (browser music gen)
- **Video Editing**: FFmpeg (exec tool) for assembly, transitions, subtitles
- **Screenshots**: Desktop/window capture via `exec` tool + screenshot.sh
- **Shell Commands**: Full shell access via `exec` tool (FFmpeg, ImageMagick, curl, Python, etc.)
- **Social Publishing**: Instagram, TikTok, YouTube, X/Twitter, LinkedIn — all via browser

## Required OpenClaw Config

The browser tool and exec tool require a node host connected to the gateway:
```bash
openclaw config set tools.allow '["*"]'
openclaw config set agents.defaults.sandbox.mode off
openclaw node install && openclaw node restart
```

## Credentials

Platform logins stored in `~/.openclaw/credentials.json`. Edit with your email/password for each platform.

## Example Usage

Send to ClawBot:
```
Create a product promo image for my coffee brand. Modern, warm colors.
```

ClawBot will:
1. Open browser → navigate to ChatGPT
2. Log in (or restore saved session)
3. Ask DALL-E to generate the image
4. Download the image
5. Return it to you

## Memory Knowledge Base

13 knowledge files in `~/.openclaw/memory/content-engine/` covering:
- Platform login flows and browser navigation
- Image/video/audio generation workflows
- Content strategy and platform optimization
- Prompt engineering per platform
- Pipeline templates and error recovery
- Safety, compliance, and accessibility
