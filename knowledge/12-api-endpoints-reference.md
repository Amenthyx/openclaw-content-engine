# API Endpoints Quick Reference

## Higgsfield AI
Base URL: `https://platform.higgsfield.ai`
Auth Headers: `hf-api-key: {key}`, `hf-secret: {secret}`

### Soul (Text-to-Image / Avatar Generation)
```
POST /api/v1/soul/generate
Content-Type: application/json

{
  "prompt": "professional woman, business attire, confident smile, studio lighting",
  "style": "photorealistic",
  "width": 1024,
  "height": 1024,
  "num_images": 1
}
```

### DoP (Image-to-Video)
```
POST /api/v1/dop/generate
Content-Type: application/json

{
  "image_url": "https://...",
  "motion_type": "natural",
  "duration": 5,
  "fps": 24
}
```

### Speak v2 (Lip-Sync)
```
POST /api/v1/speak/generate
Content-Type: application/json

{
  "avatar_image_url": "https://...",
  "audio_url": "https://...",
  "sync_quality": "high"
}
```

### Job Status Polling
```
GET /api/v1/jobs/{job_id}

Response:
{
  "status": "pending|processing|completed|failed",
  "progress": 0.75,
  "result_url": "https://...",
  "error": null
}

Poll every 5 seconds. Timeout after 5 minutes.
```

---

## OpenAI
Base URL: `https://api.openai.com/v1`
Auth: `Authorization: Bearer {api_key}`

### Image Generation (DALL-E 3)
```
POST /images/generations
{
  "model": "dall-e-3",
  "prompt": "...",
  "n": 1,
  "size": "1024x1024",
  "quality": "hd",
  "style": "vivid"
}
```

### Image Generation (gpt-image-1)
```
POST /images/generations
{
  "model": "gpt-image-1",
  "prompt": "...",
  "n": 1,
  "size": "1024x1024",
  "quality": "high",
  "background": "auto",
  "output_format": "png"
}
```

### Chat Completions (Script Writing)
```
POST /chat/completions
{
  "model": "gpt-4o",
  "messages": [
    {"role": "system", "content": "You are a content scriptwriter..."},
    {"role": "user", "content": "Write a 30-second promo script for..."}
  ],
  "temperature": 0.8
}
```

### Text-to-Speech
```
POST /audio/speech
{
  "model": "tts-1-hd",
  "input": "Hello, welcome to our product showcase...",
  "voice": "nova",
  "speed": 1.0,
  "response_format": "mp3"
}
```

### Whisper (Speech-to-Text)
```
POST /audio/transcriptions
Content-Type: multipart/form-data

file: @audio.mp3
model: whisper-1
response_format: srt  # or vtt, json, text
language: en
```

### Vision (Image Analysis)
```
POST /chat/completions
{
  "model": "gpt-4o",
  "messages": [{
    "role": "user",
    "content": [
      {"type": "text", "text": "Analyze this product image..."},
      {"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}
    ]
  }]
}
```

### Moderation (Content Safety)
```
POST /moderations
{
  "input": "text to check",
  "model": "omni-moderation-latest"
}
```

---

## ElevenLabs
Base URL: `https://api.elevenlabs.io/v1`
Auth: `xi-api-key: {api_key}`

### Text-to-Speech
```
POST /text-to-speech/{voice_id}
{
  "text": "Hello, welcome to our product showcase.",
  "model_id": "eleven_multilingual_v2",
  "voice_settings": {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.5,
    "use_speaker_boost": true
  }
}
Response: audio/mpeg binary stream
```

### Voice Cloning (Instant)
```
POST /voices/add
Content-Type: multipart/form-data

name: "Brand Voice"
files: @sample1.mp3, @sample2.mp3
description: "Professional female voice for product promos"
```

### List Voices
```
GET /voices
Response: { "voices": [{ "voice_id": "...", "name": "..." }] }
```

### Voice Preview
```
POST /text-to-speech/{voice_id}/stream
Same payload as TTS, returns streaming audio
```

---

## Stability AI
Base URL: `https://api.stability.ai/v2beta`
Auth: `Authorization: Bearer {api_key}`

### Stable Diffusion 3
```
POST /stable-image/generate/sd3
Content-Type: multipart/form-data

prompt: "..."
negative_prompt: "blurry, low quality, deformed"
aspect_ratio: "16:9"
model: "sd3.5-large"
output_format: "png"
```

### Stable Image Ultra
```
POST /stable-image/generate/ultra
Content-Type: multipart/form-data

prompt: "..."
aspect_ratio: "16:9"
output_format: "png"
```

### Image Upscale
```
POST /stable-image/upscale/creative
Content-Type: multipart/form-data

image: @input.png
prompt: "high resolution, detailed"
output_format: "png"
```

### Background Removal
```
POST /stable-image/edit/remove-background
Content-Type: multipart/form-data

image: @input.png
output_format: "png"
```

---

## Runway ML
Base URL: `https://api.runwayml.com/v1`
Auth: `Authorization: Bearer {api_key}`

### Gen-3 Alpha (Text-to-Video)
```
POST /generations
{
  "model": "gen3a_turbo",
  "prompt": "A drone shot flying over a mountain lake at sunset",
  "duration": 10,
  "width": 1280,
  "height": 768
}
```

### Gen-3 (Image-to-Video)
```
POST /generations
{
  "model": "gen3a_turbo",
  "prompt": "gentle wind blowing, camera slowly zooming in",
  "image_url": "https://...",
  "duration": 10
}
```

---

## Suno AI
Base URL: `https://api.suno.ai/v1`
Auth: `Authorization: Bearer {api_key}`

### Generate Music
```
POST /generations
{
  "prompt": "upbeat electronic lo-fi track, positive energy, 120bpm",
  "duration": 30,
  "instrumental": true,
  "style": "electronic"
}
```

### Generate with Lyrics
```
POST /generations
{
  "prompt": "pop song about summer adventures",
  "lyrics": "[Verse 1]\nSunshine on my face...\n[Chorus]\nLiving for today...",
  "duration": 120,
  "style": "pop"
}
```

---

## Google Gemini (Vision Analysis)
Base URL: `https://generativelanguage.googleapis.com/v1beta`

### Analyze Image
```
POST /models/gemini-2.0-flash:generateContent?key={api_key}
{
  "contents": [{
    "parts": [
      {"text": "Analyze this product image. Extract: product type, colors, mood, key features, target audience."},
      {"inline_data": {"mime_type": "image/png", "data": "{base64}"}}
    ]
  }]
}
```

---

## DeepSeek (Script Writing - Budget Option)
Base URL: `https://api.deepseek.com/v1`
Auth: `Authorization: Bearer {api_key}`

### Chat Completions
```
POST /chat/completions
{
  "model": "deepseek-chat",
  "messages": [
    {"role": "system", "content": "You are an expert content scriptwriter..."},
    {"role": "user", "content": "Write a 9-scene promo video script..."}
  ],
  "temperature": 0.7
}
```

---

## Dropbox
Auth: `Authorization: Bearer {access_token}`

### Upload File
```
POST https://content.dropboxapi.com/2/files/upload
Dropbox-API-Arg: {"path": "/content-engine/output/video.mp4", "mode": "overwrite"}
Content-Type: application/octet-stream

[binary file data]
```

### Download File
```
POST https://content.dropboxapi.com/2/files/download
Dropbox-API-Arg: {"path": "/content-engine/output/video.mp4"}
```

### Create Shared Link
```
POST https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings
{
  "path": "/content-engine/output/video.mp4",
  "settings": {"requested_visibility": "public"}
}
```

---

## YouTube Data API v3
Base URL: `https://www.googleapis.com/youtube/v3`
Auth: OAuth 2.0 Bearer token

### Upload Video
```
POST https://www.googleapis.com/upload/youtube/v3/videos?part=snippet,status
Content-Type: multipart/related

{
  "snippet": {
    "title": "Video Title",
    "description": "Video description with keywords...",
    "tags": ["tag1", "tag2"],
    "categoryId": "22"
  },
  "status": {
    "privacyStatus": "public",
    "selfDeclaredMadeForKids": false
  }
}

[video binary data]
```

---

## Instagram Graph API
Base URL: `https://graph.facebook.com/v19.0`
Auth: `access_token` parameter

### Publish Image
```
POST /{ig-user-id}/media
{
  "image_url": "https://publicly-accessible-url.com/image.jpg",
  "caption": "Your caption here #hashtag",
  "access_token": "{token}"
}
→ returns creation_id

POST /{ig-user-id}/media_publish
{
  "creation_id": "{creation_id}",
  "access_token": "{token}"
}
```

### Publish Reel
```
POST /{ig-user-id}/media
{
  "media_type": "REELS",
  "video_url": "https://publicly-accessible-url.com/video.mp4",
  "caption": "Your caption #hashtag",
  "access_token": "{token}"
}
→ poll status until FINISHED, then publish
```

---

## X/Twitter API v2
Base URL: `https://api.twitter.com/2`
Auth: OAuth 2.0

### Upload Media
```
POST https://upload.twitter.com/1.1/media/upload.json
Content-Type: multipart/form-data

media_data: {base64_encoded_media}
media_category: tweet_image | tweet_video
```

### Create Tweet
```
POST /tweets
{
  "text": "Your tweet text here",
  "media": {
    "media_ids": ["media_id_from_upload"]
  }
}
```

---

## Rate Limits Summary

| Platform | Limit | Reset |
|----------|-------|-------|
| OpenAI (Images) | 7 req/min (DALL-E 3) | Per minute |
| OpenAI (Chat) | 500 req/min (GPT-4o) | Per minute |
| ElevenLabs | 100 req/min | Per minute |
| Stability AI | 150 req/10s | Per 10 seconds |
| Runway ML | 50 req/min | Per minute |
| Higgsfield | Varies by plan | Per plan |
| YouTube | 10,000 units/day | Daily |
| Instagram | 200 posts/day | Daily |
| X/Twitter | 300 tweets/3h | Per 3 hours |
| Dropbox | 1,000 req/min | Per minute |

## Cost Estimates Per Operation

| Operation | Provider | Cost |
|-----------|----------|------|
| Image (1024x1024) | DALL-E 3 | $0.040 |
| Image (1024x1024 HD) | DALL-E 3 | $0.080 |
| Image (1024x1024) | gpt-image-1 | $0.040 |
| Image (SD3.5 Large) | Stability | $0.065 |
| Video (5s) | Runway Gen-3 | $0.25 |
| Video (10s) | Runway Gen-3 | $0.50 |
| TTS (1000 chars) | ElevenLabs | $0.30 |
| TTS (1000 chars) | OpenAI | $0.015 |
| Music (30s) | Suno | ~$0.10 |
| Chat (1K tokens) | GPT-4o | $0.005 |
| Chat (1K tokens) | DeepSeek | $0.001 |
| Vision (1 image) | Gemini Flash | Free |
