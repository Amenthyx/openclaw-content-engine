# OpenClaw Content Engine

## What is this?
A comprehensive vector knowledge base that transforms OpenClaw (ClawBot) into a fully autonomous, multi-platform content creation and media management system.

## Architecture
- **13 markdown knowledge files** (5,978 lines / 240KB) organized by domain
- Designed for OpenClaw's **SQLite + FTS5 + vector embedding** memory system
- Files are auto-chunked, embedded, and indexed by OpenClaw's memory engine
- Hybrid search (semantic vectors + full-text search) at runtime

## Knowledge Domains
| # | Domain | Description |
|---|--------|-------------|
| 00 | System Identity | Agent personality, decision framework, capabilities |
| 01 | Platform Auth | API auth for 15+ platforms (OAuth, keys, sessions) |
| 02 | Image Generation | DALL-E, Midjourney, SD3, Flux, Higgsfield Soul, ChatGPT browser |
| 03 | Video Generation | Higgsfield pipeline, Runway, FFmpeg command library |
| 04 | Audio & Music | ElevenLabs, OpenAI TTS, Suno AI, audio processing |
| 05 | Content Strategy | Calendars, platform specs, scripts, hashtags |
| 06 | Workflow Orchestration | 7 pipeline templates, error recovery, cost estimation |
| 07 | Prompt Engineering | Per-platform prompt patterns and templates |
| 08 | Asset Management | File organization, cloud storage, versioning |
| 09 | Analytics | KPIs, scoring, reporting, trend detection |
| 10 | Safety & Compliance | Content policies, copyright, GDPR, accessibility |
| 11 | Browser Automation | Login flows for ChatGPT, Midjourney, Canva |
| 12 | API Reference | Exact endpoints, payloads, rate limits, costs |

## Installation
```bash
bash install-to-clawbot.sh
```
Targets running `clawbot` Docker container. Copies knowledge to memory, installs skill, deploys agent config, triggers reindex.

## Key APIs Covered
Higgsfield AI, OpenAI (DALL-E/GPT/TTS/Whisper), ElevenLabs, Stability AI, Runway ML, Suno AI, Kling AI, Pika Labs, Midjourney, Dropbox, Google Drive, YouTube, Instagram, TikTok, X/Twitter, LinkedIn
