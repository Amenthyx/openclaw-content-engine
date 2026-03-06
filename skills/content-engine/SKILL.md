---
name: content-engine
description: Autonomous multi-platform content creation engine. Generates videos, images, music, and manages social media publishing via Higgsfield, OpenAI, ElevenLabs, Suno, and more.
homepage: https://github.com/openclaw/openclaw
metadata:
  {
    "openclaw":
      {
        "emoji": "🎬",
        "requires":
          {
            "env":
              [
                "OPENAI_API_KEY",
                "ELEVENLABS_API_KEY",
                "HIGGSFIELD_API_KEY",
                "HIGGSFIELD_SECRET",
              ],
          },
        "primaryEnv": "OPENAI_API_KEY",
      },
  }
---

# Content Engine

Autonomous multi-platform content creation system. Generates professional videos, images, music, voiceovers, and handles social media publishing — all from a single text instruction.

## Capabilities

- **Image Generation**: DALL-E 3, gpt-image-1, Midjourney, Stable Diffusion 3
- **Video Generation**: Higgsfield (Soul→DoP→Speak), Runway Gen-3/4, Kling AI, Pika
- **Audio/Music**: ElevenLabs TTS, Suno AI music, OpenAI TTS
- **Video Editing**: FFmpeg assembly, transitions, subtitles, color grading
- **Social Publishing**: Instagram, TikTok, YouTube, X/Twitter, LinkedIn
- **Content Strategy**: Calendar management, A/B testing, analytics

## Quick Start

### Generate a product promo video
```
Create a 30-second promo video for [product].
Style: modern, energetic.
Platforms: Instagram Reels + TikTok.
```

### Generate social media images
```
Create 5 Instagram carousel images about [topic].
Brand colors: #FF6B35, #004E89.
Style: clean, minimalist.
```

### Generate music
```
Create a 30-second upbeat background track.
Genre: electronic/lo-fi.
Mood: positive, energetic.
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes | For DALL-E, GPT, TTS, Whisper |
| `ELEVENLABS_API_KEY` | Yes | For voice cloning and TTS |
| `HIGGSFIELD_API_KEY` | Yes | For avatar video generation |
| `HIGGSFIELD_SECRET` | Yes | Higgsfield API secret |
| `SUNO_API_KEY` | Optional | For AI music generation |
| `RUNWAY_API_KEY` | Optional | For Runway Gen-3/4 video |
| `STABILITY_API_KEY` | Optional | For Stable Diffusion 3 |
| `DROPBOX_ACCESS_TOKEN` | Optional | For cloud storage |
| `YOUTUBE_CLIENT_ID` | Optional | For YouTube uploads |
| `YOUTUBE_CLIENT_SECRET` | Optional | For YouTube uploads |
| `INSTAGRAM_ACCESS_TOKEN` | Optional | For Instagram publishing |
| `TIKTOK_ACCESS_TOKEN` | Optional | For TikTok publishing |
| `TWITTER_BEARER_TOKEN` | Optional | For X/Twitter publishing |

## Pipelines

### Product Promo Video (Full)
1. Analyze product image (Gemini Vision / GPT-4 Vision)
2. Generate 9-scene script
3. Generate scene images (DALL-E / Midjourney)
4. Generate avatar frames (Higgsfield Soul)
5. Animate scenes (Higgsfield DoP)
6. Generate voiceover (ElevenLabs)
7. Lip-sync avatar (Higgsfield Speak v2)
8. Generate background music (Suno AI)
9. Assemble with FFmpeg (transitions, subtitles, music)
10. Export per platform (9:16, 16:9, 1:1)
11. Upload to platforms

### Social Image Post
1. Generate caption + visual concept
2. Generate image (DALL-E / SD3)
3. Add branding (text overlay, colors, logo)
4. Resize per platform
5. Generate hashtags
6. Publish

### Audio/Podcast
1. Generate script from topic
2. Generate narration (ElevenLabs)
3. Generate intro/outro music (Suno)
4. Assemble audio (FFmpeg)
5. Generate metadata
6. Distribute

## Platform Export Specs

| Platform | Resolution | Duration | Format |
|----------|-----------|----------|--------|
| Instagram Reels | 1080x1920 | 15-90s | H.264 MP4 |
| TikTok | 1080x1920 | 15-180s | H.264 MP4 |
| YouTube Shorts | 1080x1920 | <60s | H.264 MP4 |
| YouTube Long | 1920x1080 | 8-20min | H.264 MP4 |
| X/Twitter | 1280x720+ | <140s | H.264 MP4 |
| LinkedIn | 1080x1080 | 30-120s | H.264 MP4 |

## Memory Integration

This skill's knowledge base is stored in OpenClaw's memory system at `memory/content-engine/`. It includes:

- `01-platform-authentication.md` — API auth for all platforms
- `02-image-generation.md` — Image creation and editing workflows
- `03-video-generation.md` — Video generation and FFmpeg commands
- `04-audio-music.md` — Audio/music generation and processing
- `05-content-strategy.md` — Content planning and platform optimization
- `06-workflow-orchestration.md` — Pipeline templates and error recovery
- `07-prompt-engineering.md` — Prompt patterns for every platform
- `08-asset-management.md` — File organization and cloud storage
- `09-analytics-optimization.md` — Performance tracking and reporting
- `10-safety-compliance.md` — Content policies and legal requirements

OpenClaw automatically searches this knowledge when handling content creation requests.
