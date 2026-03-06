# OpenClaw Content Engine

## What is this?
A comprehensive knowledge base that transforms OpenClaw (ClawBot) into a fully autonomous content creation agent. Operates entirely through **browser automation** — no API keys needed. Logs into platforms with email/password, creates content through the UI, and publishes to social media.

## Architecture
- **13 markdown knowledge files** organized by domain
- Designed for OpenClaw's **SQLite + FTS5 + vector embedding** memory system
- All platform interactions via **Chromium browser on Xvfb** (visible via noVNC)
- **FFmpeg** for local video/audio processing
- Credentials stored in `credentials.json` (email/password per platform)
- Session cookies cached for persistent login

## Key Principle
No API keys. No tokens. ClawBot logs into every platform like a human user and performs all actions through the browser UI.

## Platforms Supported (via browser login)
ChatGPT (DALL-E images + scripts), Higgsfield (avatar videos), ElevenLabs (voiceovers), Runway ML (cinematic video), Suno AI (music), Midjourney (via Discord), Canva (designs), Stability AI (SD3), Kling AI (video), Pika (video), Instagram, TikTok, YouTube, X/Twitter, LinkedIn, Dropbox, Google Drive

## Installation
```bash
bash install-to-clawbot.sh
docker exec -it clawbot nano /home/node/.openclaw/credentials.json  # add your logins
```
