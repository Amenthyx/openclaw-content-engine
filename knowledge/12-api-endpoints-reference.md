# Platform URLs & Browser Workflow Reference

All operations are performed through browser automation — no API keys. This file provides the exact URLs, UI navigation paths, and browser selectors for each platform.

---

## ChatGPT — Image Generation + Script Writing
- **Login URL**: https://chat.openai.com
- **Login flow**: Click "Log in" → email → password → 2FA
- **Session check**: Look for message input textarea
- **New chat**: Click "New chat" or navigate to https://chat.openai.com

### Image Generation
```
1. Open new chat
2. Type: "Generate an image: [prompt]"
3. Wait for image (15-45s)
4. Right-click image → Save / extract src URL
```

### Script Writing
```
1. Open new chat
2. Type: "Write a video script for [topic]..."
3. Copy response text
```

### Image Editing
```
1. In same conversation with generated image
2. Type: "Edit this image: [changes]"
3. Wait for new version
```

---

## Higgsfield — Avatar Video Pipeline
- **Login URL**: https://platform.higgsfield.ai/login
- **Session check**: Dashboard elements visible

### Soul (Text-to-Image)
```
Navigate to Soul section → Enter prompt → Select style → Generate → Download
Best for: avatars, presenter images, character-consistent faces
```

### DoP (Image-to-Video)
```
Navigate to DoP section → Upload image → Set motion + duration → Generate → Download
Output: 5-second animated video clips
```

### Speak v2 (Lip-Sync)
```
Navigate to Speak section → Upload avatar image + audio → Generate → Download
Output: lip-synced talking-head video
```

---

## ElevenLabs — Voice & TTS
- **Login URL**: https://elevenlabs.io/sign-in
- **TTS page**: https://elevenlabs.io/app/speech-synthesis
- **Voices page**: https://elevenlabs.io/app/voice-lab

### Text-to-Speech
```
Navigate to Speech Synthesis → Select voice → Paste text → Adjust settings → Generate → Download MP3
```

### Voice Cloning
```
Navigate to Voice Lab → Add Voice → Instant Clone → Upload samples → Name voice → Add
```

---

## Runway ML — Cinematic Video
- **Login URL**: https://app.runwayml.com/login
- **Session check**: Workspace visible

### Text-to-Video
```
Click Generate → Select Gen-3/Gen-4 → Text to Video → Enter prompt → Set duration → Generate → Download
```

### Image-to-Video
```
Same flow but select Image to Video → Upload image → Enter motion prompt → Generate → Download
```

---

## Suno AI — Music Generation
- **Login URL**: https://suno.com (Google/Discord/email sign-in)

### Generate Music
```
Click Create → Enter description (genre, mood, tempo, duration) → Create → Download
For lyrics: toggle Custom mode → paste lyrics → Create
```

---

## Midjourney — Artistic Images (via Discord)
- **Login URL**: https://discord.com/login
- **Bot DM**: Navigate to Midjourney Bot in DMs

### Generate
```
Type: /imagine prompt: [prompt] --ar 9:16 --v 6.1 --s 750
Wait 30-90s → Click U1-U4 to upscale → Open in browser → Save
```

### Variations
```
Click V1-V4 for variations of a result
/describe [image] — reverse-engineer prompt from image
/blend [img1] [img2] — merge two images
```

---

## Stability AI — SD3 Images
- **Login URL**: https://platform.stability.ai
- **Playground**: Navigate to image generation after login

### Generate
```
Select model (SD3.5, Ultra) → Enter prompt + negative prompt → Set aspect ratio → Generate → Download
```

---

## Kling AI — Video Generation
- **Login URL**: https://klingai.com

### Generate
```
Select Text/Image to Video → Enter prompt or upload → Set duration → Generate → Download
```

---

## Pika Labs — Video Generation
- **Login URL**: https://pika.art

### Generate
```
Enter prompt or upload image → Set parameters → Generate → Download
```

---

## Canva — Design & Templates
- **Login URL**: https://www.canva.com/login

### Create Design
```
Click "Create a design" → Select format → Browse templates → Customize → Download (PNG/MP4/PDF)
```

---

## Social Media Publishing URLs

### Instagram
- **Login**: https://www.instagram.com/accounts/login/
- **Post**: Click "+" icon → Upload → Caption → Hashtags → Share
- **Reel**: Click "+" → Select video → Caption → Share
- **Story**: Click profile "+" → Upload → Share
- **Analytics**: https://www.instagram.com/accounts/insights/

### TikTok
- **Login**: https://www.tiktok.com/login
- **Upload**: https://www.tiktok.com/upload
- **Post**: Upload video → Caption + hashtags + sounds → Post
- **Analytics**: https://www.tiktok.com/analytics

### YouTube
- **Login**: https://studio.youtube.com (Google account)
- **Upload**: Click "Create" → "Upload video" → File → Metadata → Publish
- **Shorts**: Same flow, video must be < 60s and 9:16
- **Analytics**: https://studio.youtube.com/channel/analytics

### X / Twitter
- **Login**: https://x.com/i/flow/login
- **Post**: Click compose → Text + media → Post
- **Analytics**: https://analytics.twitter.com

### LinkedIn
- **Login**: https://www.linkedin.com/login
- **Post**: Click "Start a post" → Text + media → Post
- **Analytics**: https://www.linkedin.com/analytics/

---

## Cloud Storage (Browser)

### Dropbox
- **Login**: https://www.dropbox.com/login
- **Upload**: Click "Upload" → Select files → Choose folder
- **Share**: Right-click file → "Share" → "Copy link"
- **Download**: Click file → "Download"

### Google Drive
- **Login**: https://drive.google.com (Google account)
- **Upload**: Click "New" → "File upload" → Select files
- **Share**: Right-click → "Share" → Set permissions → Copy link
- **Download**: Right-click → "Download"

---

## FFmpeg — Local Processing (No Browser)

FFmpeg runs locally inside the Docker container. No login needed.

### Key Commands
```bash
# Concatenate clips
ffmpeg -f concat -safe 0 -i list.txt -c copy output.mp4

# Add background music with ducking
ffmpeg -i video.mp4 -i music.mp3 -filter_complex "[1:a]volume=0.2[bg];[0:a][bg]amix=inputs=2" output.mp4

# Burn-in subtitles
ffmpeg -i video.mp4 -vf "subtitles=subs.srt:force_style='FontSize=24'" output.mp4

# Export for Instagram Reels (9:16, 1080x1920)
ffmpeg -i input.mp4 -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2" -c:v libx264 -b:v 5M -c:a aac output_reel.mp4

# Export for YouTube (16:9, 1920x1080)
ffmpeg -i input.mp4 -vf "scale=1920:1080" -c:v libx264 -b:v 8M -c:a aac output_yt.mp4

# Generate thumbnail from video
ffmpeg -i video.mp4 -ss 00:00:05 -frames:v 1 thumbnail.png

# Normalize audio to -14 LUFS
ffmpeg -i input.mp4 -af loudnorm=I=-14:TP=-1:LRA=11 output.mp4
```

---

## Cost Summary (Subscription-Based, No Per-Use API Fees)

| Platform | Subscription | What You Get |
|----------|-------------|--------------|
| ChatGPT Plus | $20/month | Unlimited DALL-E images, GPT-4o, script writing |
| ChatGPT Pro | $200/month | Higher limits, priority access |
| ElevenLabs Starter | $5/month | 30 min TTS, 3 voice clones |
| ElevenLabs Creator | $22/month | 100 min TTS, 10 voice clones |
| Runway Standard | $15/month | 625 credits (~40 videos) |
| Suno Pro | $10/month | 500 songs/month |
| Midjourney Basic | $10/month | ~200 images |
| Canva Pro | $13/month | Unlimited designs |
| Stability AI | Free tier | Limited generations |
| Higgsfield | Free tier + paid | Varies |
| Kling AI | Free tier + paid | Varies |
| Pika | Free tier + paid | Varies |
