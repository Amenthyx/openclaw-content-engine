# Platform Authentication — Browser Login (No API Keys)

OpenClaw Content Engine operates entirely through browser automation. It logs into each platform as a human user using email/password credentials, navigates the UI, and performs all actions through the browser. No API keys required.

## Architecture

ClawBot runs inside a Docker container with:
- **Chromium** browser (headless or visible via VNC)
- **Xvfb** virtual display (DISPLAY=:99, 1920x1080)
- **x11vnc + noVNC** for remote viewing/debugging (http://localhost:6080)
- Browser automation via Playwright or Puppeteer

All interactions happen through the browser — the same way a human would use these platforms.

---

## Credential Storage

Credentials are stored in a local JSON file inside the Docker volume, never committed to git.

### credentials.json
```json
{
  "chatgpt": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "higgsfield": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "elevenlabs": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "runway": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "suno": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "stability": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "midjourney_discord": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "kling": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "pika": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "canva": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "dropbox": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "google": {
    "email": "",
    "password": "",
    "2fa_secret": "",
    "note": "Used for YouTube, Google Drive, Gemini"
  },
  "instagram": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "tiktok": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "twitter": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  },
  "linkedin": {
    "email": "",
    "password": "",
    "2fa_secret": ""
  }
}
```

### 2FA Handling
- If `2fa_secret` is provided (TOTP base32 key), ClawBot generates the 6-digit code automatically
- If `2fa_secret` is empty and 2FA is enabled, ClawBot pauses and asks the user for the code
- User can also solve 2FA manually via VNC at http://localhost:6080

---

## Login Flows Per Platform

### ChatGPT (chat.openai.com) — IMAGE GENERATION + SCRIPT WRITING

#### Login
```
1. Navigate to https://chat.openai.com
2. Click "Log in"
3. Enter email → Click "Continue"
4. Enter password → Click "Continue"
5. Handle 2FA if prompted
6. Wait for chat interface to load (look for message input textarea)
7. Verify login: check for user avatar in top-right corner
```

#### Session Persistence
- Save cookies after login to `/home/node/.openclaw/sessions/chatgpt-session.json`
- Reload cookies on next launch to skip login
- Cookies valid ~14 days
- If session expired: auto re-login

#### Image Generation
```
1. Click "New chat" or navigate to https://chat.openai.com
2. Type: "Generate an image: [detailed prompt with style, lighting, composition]"
3. Wait for DALL-E to generate (15-45 seconds)
4. Right-click image → "Save image as" OR extract image URL from page
5. For variations: "Create 3 variations of this with [changes]"
6. For edits: "Edit this image: [description of changes]"
7. To force exact prompt: "Generate exactly as described, do not modify the prompt"
```

#### Script Writing
```
1. Open new chat
2. Type: "Write a [duration]-second video script for [topic].
   Format each scene as: Scene N: [visual description] | [voiceover text] | [duration]"
3. Copy the response
```

#### Tips
- Specify aspect ratio: "in portrait 9:16 format"
- Keep one conversation per project for style consistency
- Download images immediately — CDN URLs may expire
- ChatGPT Plus/Pro = higher limits and faster generation

---

### Higgsfield (platform.higgsfield.ai) — AVATAR VIDEO GENERATION

#### Login
```
1. Navigate to https://platform.higgsfield.ai/login
2. Enter email and password
3. Click "Sign In"
4. Handle 2FA if prompted
5. Wait for dashboard to load
```

#### Soul — Text-to-Image (Avatars)
```
1. Navigate to Soul / Text-to-Image section
2. Enter prompt: "professional woman, 30s, business attire, confident smile, studio lighting"
3. Select style (photorealistic, artistic, etc.)
4. Set dimensions (1024x1024, portrait, landscape)
5. Click "Generate"
6. Wait 10-30 seconds
7. Click "Download" on the generated image
```

#### DoP — Image-to-Video
```
1. Navigate to DoP / Image-to-Video section
2. Upload the source image (from Soul or any image)
3. Set motion type and duration (5s default)
4. Click "Generate"
5. Wait for processing (check progress indicator)
6. Download completed video
```

#### Speak v2 — Lip-Sync
```
1. Navigate to Speak section
2. Upload avatar image
3. Upload audio file (MP3/WAV voiceover)
4. Select sync quality (standard/high)
5. Click "Generate"
6. Wait 30-120 seconds
7. Download lip-synced video
```

#### Full Pipeline
```
Soul → generate avatar image → download
DoP → upload image, animate → download video
Speak → upload avatar + audio, lip-sync → download final
```

---

### ElevenLabs (elevenlabs.io) — VOICEOVER + VOICE CLONING

#### Login
```
1. Navigate to https://elevenlabs.io/sign-in
2. Enter email and password
3. Click "Sign In"
4. Wait for dashboard to load
```

#### Text-to-Speech
```
1. Navigate to https://elevenlabs.io/app/speech-synthesis
2. Select voice from dropdown (or cloned voice)
3. Paste voiceover text into text area
4. Adjust sliders: Stability, Similarity, Style
5. Click "Generate"
6. Wait 5-30 seconds
7. Click download button → saves as MP3
```

#### Voice Cloning
```
1. Navigate to "Voices" → "Add Voice" → "Instant Voice Clone"
2. Upload audio samples (minimum 1 minute, clean recording)
3. Name the voice (e.g., "Brand Voice")
4. Click "Add Voice"
5. New voice appears in TTS dropdown
```

---

### Runway ML (app.runwayml.com) — CINEMATIC VIDEO

#### Login
```
1. Navigate to https://app.runwayml.com/login
2. Enter email and password (or Google SSO)
3. Click "Log In"
4. Wait for workspace to load
```

#### Text-to-Video
```
1. Click "Generate" → Select "Gen-3 Alpha" or "Gen-4 Turbo"
2. Choose "Text to Video"
3. Enter prompt (describe scene, motion, camera movement)
4. Set duration (5s or 10s)
5. Click "Generate"
6. Wait 1-5 minutes
7. Preview → Download MP4
```

#### Image-to-Video
```
1. Select "Image to Video"
2. Upload source image
3. Enter motion prompt ("gentle zoom in, wind blowing hair")
4. Generate → Wait → Download
```

---

### Suno AI (suno.com) — MUSIC GENERATION

#### Login
```
1. Navigate to https://suno.com
2. Click "Sign In" (Google, Discord, or email)
3. Complete login flow
4. Wait for creation page
```

#### Generate Music
```
1. Click "Create"
2. Enter description: "upbeat electronic lo-fi, positive energy, 120bpm, 30 seconds"
3. For custom lyrics: toggle "Custom" mode, paste lyrics
4. Click "Create"
5. Wait 30-60 seconds
6. Preview tracks → Download preferred version (MP3)
```

---

### Midjourney (via Discord) — ARTISTIC IMAGES

#### Login to Discord
```
1. Navigate to https://discord.com/login
2. Enter email and password
3. Handle 2FA if prompted
4. Wait for Discord to load
```

#### Generate Images
```
1. Navigate to Midjourney Bot DM or server channel
2. Type: /imagine prompt: [detailed prompt] --ar 9:16 --v 6.1 --s 750
3. Press Enter
4. Wait 30-90 seconds for 4-image grid
5. Click U1-U4 to upscale the best one
6. Click upscaled image → "Open in Browser" → Save
```

---

### Canva (canva.com) — DESIGN + TEMPLATES

#### Login
```
1. Navigate to https://www.canva.com/login
2. Enter email and password (or Google SSO)
3. Wait for dashboard
```

#### Create Design
```
1. Click "Create a design" → Select type (Instagram Post, Reel, etc.)
2. Browse/search templates
3. Customize: replace text, images, colors
4. Apply brand kit if set up
5. Click "Share" → "Download" → Select format (PNG, MP4, PDF)
```

---

### Stability AI (platform.stability.ai) — SD3 IMAGES

#### Login
```
1. Navigate to https://platform.stability.ai
2. Sign in (Google or email)
3. Navigate to image generation playground
```

#### Generate
```
1. Select model (SD 3.5, Ultra)
2. Enter positive prompt + negative prompt
3. Set aspect ratio, style
4. Click "Generate" → Download
```

---

### Kling AI (klingai.com) — VIDEO

#### Login
```
1. Navigate to https://klingai.com
2. Sign in (Google or email)
```

#### Generate
```
1. Select "Text to Video" or "Image to Video"
2. Enter prompt / upload image
3. Set duration and quality → Generate → Download
```

---

### Pika Labs (pika.art) — VIDEO

#### Login
```
1. Navigate to https://pika.art
2. Sign in (Google or Discord)
```

#### Generate
```
1. Enter prompt or upload image
2. Set parameters → Generate → Download
```

---

## Social Media Publishing (Browser)

### Instagram (instagram.com)
```
1. Login at https://www.instagram.com/accounts/login/
2. To post image: Click "+" → Select file → Add filter/edit → Write caption → Add hashtags → Share
3. To post Reel: Click "+" → Select video → Add caption, music, cover → Share
4. To post Story: Click profile pic "+" → Select media → Add stickers/text → Share
```

### TikTok (tiktok.com)
```
1. Login at https://www.tiktok.com/login
2. Click "Upload" (or navigate to https://www.tiktok.com/upload)
3. Select video file
4. Add caption, hashtags, sounds
5. Set visibility and options
6. Click "Post"
```

### YouTube (studio.youtube.com)
```
1. Login at https://studio.youtube.com (Google account)
2. Click "Create" → "Upload video"
3. Select video file
4. Fill: Title, Description, Tags, Thumbnail
5. Set visibility (Public/Unlisted/Private)
6. Click "Publish"
```

### X/Twitter (x.com)
```
1. Login at https://x.com/i/flow/login
2. Click compose button
3. Type text, attach media
4. Click "Post"
```

### LinkedIn (linkedin.com)
```
1. Login at https://www.linkedin.com/login
2. Click "Start a post"
3. Add text, attach media
4. Click "Post"
```

---

## Session Management

### Cookie Persistence Strategy
```
After successful login on any platform:
1. Export browser cookies/storage to:
   /home/node/.openclaw/sessions/{platform}-session.json
2. On next operation, restore session from file
3. Navigate to platform → check if still logged in
4. If expired → re-login with credentials from credentials.json → save new session
```

### Session Health Check (run before each operation)
```
Platform        | Check Selector / Element
----------------|------------------------------------------
ChatGPT         | Chat input textarea visible
Higgsfield      | Dashboard or project list visible
ElevenLabs      | Speech synthesis controls visible
Runway          | Workspace / generate button visible
Discord/MJ      | Message input box visible
Instagram       | Home feed or profile icon visible
TikTok          | Upload button or feed visible
YouTube Studio  | Channel dashboard visible
X/Twitter       | Compose button visible
LinkedIn        | Feed or post button visible
```

---

## Human-Like Behavior (Anti-Detection)

- Random delays between actions: 1-5 seconds
- Typing speed: 50-150ms per keystroke (randomized)
- Mouse movements: natural curves, not straight lines
- Scroll naturally before clicking elements
- Don't exceed human-speed action rates
- Take 2-5 minute breaks every 10 heavy operations
- Use full Chromium on Xvfb (not headless mode)
- Standard 1920x1080 resolution, normal user agent
- Accept cookie banners, dismiss popups like a real user
- Rotate between platforms — don't hammer one platform

---

## CAPTCHA Handling

When CAPTCHA appears:
1. Pause automation immediately
2. Notify user via ClawBot's messaging channel (Telegram/Discord/etc.)
3. User solves CAPTCHA manually via noVNC at http://localhost:6080
4. Resume automation after CAPTCHA is cleared
5. Slow down subsequent actions to avoid triggering more CAPTCHAs

---

## Credential Security

- `credentials.json` lives inside Docker volume, never in git
- File permissions: `chmod 600` (owner read/write only)
- Never log, echo, or display credentials in output
- TOTP secrets enable fully automatic 2FA
- Credentials read only at login time
- Sessions cached as cookies to minimize credential access
