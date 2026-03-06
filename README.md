# OpenClaw Content Engine

Autonomous multi-platform content creation knowledge base for ClawBot. Transforms OpenClaw into a fully independent media manager capable of generating videos, images, music, voiceovers, and publishing across all major social platforms — without human intervention.

## What's Inside

**13 knowledge files (6,000+ lines / 240KB)** that get indexed into OpenClaw's memory system:

| Domain | What It Covers |
|--------|---------------|
| **Platform Auth** | API authentication for 15+ platforms (Higgsfield, OpenAI, ElevenLabs, Runway, Stability, Suno, Dropbox, YouTube, Instagram, TikTok, X/Twitter, LinkedIn) |
| **Image Generation** | DALL-E 3, gpt-image-1, Higgsfield Soul, ChatGPT browser, Midjourney, Stable Diffusion 3, Flux — with prompt engineering per platform |
| **Video Generation** | Higgsfield pipeline (Soul→DoP→Speak), Runway Gen-3/4, Kling AI, Pika Labs + 20+ FFmpeg commands |
| **Audio & Music** | ElevenLabs TTS, voice cloning, OpenAI TTS, Suno AI music, FFmpeg audio processing |
| **Content Strategy** | Platform specs (aspect ratios, durations, hashtags), posting schedules, script frameworks (AIDA, PAS, StoryBrand), brand voice templates |
| **Workflow Orchestration** | 7 end-to-end pipeline templates, error recovery, provider fallback chains, cost estimation |
| **Prompt Engineering** | Platform-specific prompt patterns, 10 content-type templates, dynamic prompt construction |
| **Asset Management** | File naming, folder structure, cloud storage (Dropbox, S3, GDrive), versioning, deduplication |
| **Analytics** | Platform analytics APIs, KPI definitions, performance scoring, automated reporting templates |
| **Safety & Compliance** | Content policies per platform, AI disclosure requirements, copyright, GDPR, accessibility |
| **Browser Automation** | Login flows for ChatGPT, Midjourney, Canva — for when APIs aren't available |
| **API Reference** | Exact endpoints, payloads, headers, rate limits, and cost-per-operation for every API |

## Prerequisites

- **Docker** installed and running
- **ClawBot container** running (from [OpenClaw-Docker](https://github.com/Amenthyx/OpenClaw-Docker))
- At least one AI provider API key configured in ClawBot's `.env`

### Recommended API Keys

| Key | Required | What It Enables |
|-----|----------|----------------|
| `OPENAI_API_KEY` | Yes | Image generation (DALL-E), script writing (GPT), voiceover (TTS), transcription (Whisper), vision analysis |
| `ELEVENLABS_API_KEY` | Yes | High-quality voiceovers, voice cloning |
| `HIGGSFIELD_API_KEY` + `HIGGSFIELD_SECRET` | Yes | Avatar video generation (Soul→DoP→Speak pipeline) |
| `SUNO_API_KEY` | Optional | AI music generation |
| `RUNWAY_API_KEY` | Optional | Runway Gen-3/4 cinematic video |
| `STABILITY_API_KEY` | Optional | Stable Diffusion 3 images |
| `DROPBOX_ACCESS_TOKEN` | Optional | Cloud asset storage |
| `YOUTUBE_CLIENT_ID` + `YOUTUBE_CLIENT_SECRET` | Optional | YouTube video uploads |
| `INSTAGRAM_ACCESS_TOKEN` | Optional | Instagram publishing |
| `TIKTOK_ACCESS_TOKEN` | Optional | TikTok publishing |
| `TWITTER_BEARER_TOKEN` | Optional | X/Twitter publishing |

## Installation

### Option 1: One-Command Install (Recommended)

Make sure your ClawBot container is running, then:

```bash
git clone https://github.com/Amenthyx/openclaw-content-engine.git
cd openclaw-content-engine
bash install-to-clawbot.sh
```

This will:
1. Copy all 13 knowledge files into ClawBot's memory (`~/.openclaw/memory/content-engine/`)
2. Install the `content-engine` skill (`~/.openclaw/skills/content-engine/`)
3. Deploy agent instructions (`~/.openclaw/agents/main/`)
4. Trigger a memory reindex so everything is searchable immediately

### Option 2: Manual Install

If your container has a different name or you want to install manually:

```bash
# Set your container name (default: clawbot)
export CLAWBOT_CONTAINER=your-container-name

# Run the installer
bash install-to-clawbot.sh
```

### Option 3: Direct Copy (No Docker)

If you're running OpenClaw directly (not in Docker):

```bash
# Copy knowledge files
cp -r knowledge/ ~/.openclaw/memory/content-engine/

# Copy skill
cp -r skills/content-engine/ ~/.openclaw/skills/content-engine/

# Trigger reindex
openclaw memory sync --force
```

## Verify Installation

After installing, verify everything is working:

```bash
# Check knowledge files are indexed
docker exec clawbot openclaw memory status

# Test a search query
docker exec -u node clawbot openclaw memory search "how to generate video with higgsfield"

# Test another query
docker exec -u node clawbot openclaw memory search "instagram reel aspect ratio"
```

You should see relevant results from the knowledge base.

## Usage

Once installed, just message ClawBot naturally. The knowledge base is searched automatically when handling content requests.

### Example Prompts

**Generate a product promo video:**
```
Create a 30-second promo video for my coffee brand "BeanCraft".
Style: warm, artisan, modern.
Platforms: Instagram Reels + TikTok.
```

**Generate social media images:**
```
Create 5 Instagram carousel images about AI trends in 2026.
Brand colors: #FF6B35, #004E89.
Style: clean, minimalist, professional.
```

**Create a full content package:**
```
Plan a week of social media content for a fitness brand.
Platforms: Instagram, TikTok, YouTube Shorts.
Include: images, short videos, captions, and hashtags.
```

**Generate music and voiceover:**
```
Create a 30-second upbeat background track (electronic/lo-fi)
and record a voiceover saying: "Welcome to BeanCraft — where
every cup tells a story."
```

**Publish content:**
```
Upload the latest video to Instagram Reels and TikTok
with optimized captions and hashtags for each platform.
```

## How It Works

```
User Message → OpenClaw Agent
                    ↓
            Memory Search (vector + FTS5)
                    ↓
            Retrieve relevant knowledge
            (auth, prompts, pipelines, specs)
                    ↓
            Execute pipeline autonomously
            (generate → assemble → optimize → publish)
                    ↓
            Deliver results + cost report
```

OpenClaw's built-in memory engine handles:
- **Chunking**: Each markdown section becomes a searchable chunk
- **Embedding**: Vector embeddings generated via configured provider (OpenAI, Gemini, or Voyage)
- **Hybrid Search**: Combines semantic vector similarity + full-text keyword matching
- **Relevance Ranking**: Returns the most relevant knowledge for any query

## Project Structure

```
openclaw-content-engine/
├── .ai/
│   └── context_base.md              # AI agent context file
├── knowledge/                        # Knowledge base (13 files)
│   ├── 00-system-identity.md         # Agent identity & decision framework
│   ├── 01-platform-authentication.md # Auth for 15+ platforms
│   ├── 02-image-generation.md        # Image creation & editing
│   ├── 03-video-generation.md        # Video generation & FFmpeg
│   ├── 04-audio-music.md             # Audio, TTS, music generation
│   ├── 05-content-strategy.md        # Content planning & optimization
│   ├── 06-workflow-orchestration.md   # Pipeline templates & error recovery
│   ├── 07-prompt-engineering.md       # Platform-specific prompt patterns
│   ├── 08-asset-management.md         # File organization & storage
│   ├── 09-analytics-optimization.md   # Performance tracking & reporting
│   ├── 10-safety-compliance.md        # Content policies & legal
│   ├── 11-browser-automation.md       # Login flows & session management
│   └── 12-api-endpoints-reference.md  # API URLs, payloads, costs
├── skills/
│   └── content-engine/
│       └── SKILL.md                  # OpenClaw skill definition
├── deploy.sh                         # Generic deploy script
├── install-to-clawbot.sh             # ClawBot Docker installer
└── README.md
```

## Updating

Pull the latest knowledge base and reinstall:

```bash
cd openclaw-content-engine
git pull
bash install-to-clawbot.sh
```

The installer is idempotent — safe to run multiple times.

## Troubleshooting

**"Container 'clawbot' is not running"**
Start your ClawBot container first:
```bash
cd /path/to/OpenClaw-Docker
docker compose up -d
```

**Memory search returns no results**
Wait for the reindex to complete, or force it:
```bash
docker exec -u node clawbot openclaw memory sync --force
```

**API calls failing**
Check that the required API keys are set in your `.env` file and the container has been restarted after adding them.

**FFmpeg commands not working**
The ClawBot Docker image includes FFmpeg by default. If running OpenClaw outside Docker, install FFmpeg separately:
```bash
# Ubuntu/Debian
sudo apt install ffmpeg

# macOS
brew install ffmpeg

# Windows
winget install ffmpeg
```

## License

MIT
