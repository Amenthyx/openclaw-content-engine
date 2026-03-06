# Video Generation & Editing

Comprehensive reference for AI-powered video generation, FFmpeg processing, and video assembly workflows.

---

## Text-to-Video / Image-to-Video

### Higgsfield AI Pipeline (PRIMARY)

Base URL: `https://platform.higgsfield.ai`
Authentication: Headers `hf-api-key` and `hf-secret`

#### Soul (Text-to-Image)

Generate a still image from a text prompt.

- **Endpoint**: `POST /api/v1/soul/generate`
- **Payload**:
```json
{
  "prompt": "A professional woman in a modern office, cinematic lighting, 8K",
  "negative_prompt": "blurry, low quality, distorted face",
  "style": "photorealistic",
  "width": 1024,
  "height": 1024,
  "num_inference_steps": 30,
  "guidance_scale": 7.5
}
```
- **Style Options**: `photorealistic`, `cinematic`, `anime`, `illustration`, `3d-render`
- **Resolution**: 512x512, 768x768, 1024x1024 (square); 768x1344 (portrait 9:16); 1344x768 (landscape 16:9)
- **Response**: Returns a job ID for async polling

#### DoP (Image-to-Video)

Animate a still image into a 5-second video clip.

- **Endpoint**: `POST /api/v1/dop/generate`
- **Payload**:
```json
{
  "image_url": "https://...",
  "prompt": "slow camera zoom in, gentle wind blowing hair",
  "motion_strength": 0.7,
  "duration": 5,
  "fps": 24
}
```
- **Input Image Requirements**: JPEG or PNG, minimum 512x512, maximum 2048x2048, clear subject
- **Motion Control**: `motion_strength` 0.0-1.0 (higher = more movement, risk of artifacts above 0.8)
- **Duration**: Fixed 5-second clips (chain multiple for longer videos)
- **Response**: Returns a job ID for async polling

#### Speak v2 (Lip-Sync)

Generate a talking-head video with lip-synced audio.

- **Endpoint**: `POST /api/v1/speak/v2/generate`
- **Payload**:
```json
{
  "avatar_id": "avatar_abc123",
  "audio_url": "https://...audio.mp3",
  "presenter_photo_url": "https://...face.jpg",
  "gesture_mode": "natural",
  "quality": "high"
}
```
- **Avatar**: Use a pre-registered avatar ID or provide `presenter_photo_url` for one-off
- **Audio Input**: MP3 or WAV, 16kHz+ sample rate, mono or stereo, max 120 seconds
- **Quality Settings**: `draft` (fast, lower quality), `standard`, `high` (slow, best sync)
- **Gesture Mode**: `none`, `minimal`, `natural`, `expressive`

#### Async Job Polling Pattern

All Higgsfield endpoints return a job ID. Poll for completion:

```
GET /api/v1/jobs/{job_id}/status
Headers: hf-api-key, hf-secret
```

**Poll Strategy**:
- Initial delay: 10 seconds
- Poll interval: 5 seconds for Soul, 15 seconds for DoP/Speak
- Timeout: 120 seconds for Soul, 300 seconds for DoP, 600 seconds for Speak
- Status values: `queued`, `processing`, `completed`, `failed`
- On `completed`: response includes `output_url` for the asset

**Error Handling Per Step**:
- **Soul failure**: Retry with simplified prompt (remove complex details), reduce `num_inference_steps`
- **DoP failure**: Check image resolution meets minimum, reduce `motion_strength`, verify image URL accessibility
- **Speak failure**: Verify audio duration under limit, check audio format, ensure face is clearly visible in photo
- **Rate limits**: Implement exponential backoff starting at 30 seconds

#### Full Pipeline: Soul -> DoP -> Speak -> FFmpeg Merge

1. Generate scene images with Soul (parallelizable across scenes)
2. Animate each image with DoP (parallelizable)
3. Generate presenter segments with Speak (sequential if same avatar)
4. Aggregate all clips
5. Merge with FFmpeg concat + add audio track

---

### Runway ML

#### Gen-3 Alpha / Gen-4 Turbo

- **Base URL**: `https://api.runwayml.com/v1`
- **Auth**: Bearer token in `Authorization` header

**Text-to-Video**:
```
POST /v1/text-to-video
{
  "model": "gen4-turbo",
  "prompt": "A golden retriever running through a sunlit meadow, slow motion, cinematic",
  "duration": 10,
  "resolution": "1080p",
  "motion": {
    "camera": "slow_zoom_in",
    "intensity": 0.6
  }
}
```

**Image-to-Video**:
```
POST /v1/image-to-video
{
  "model": "gen4-turbo",
  "image_url": "https://...",
  "prompt": "the subject turns to face the camera and smiles",
  "duration": 5,
  "motion": {
    "camera": "orbit_right",
    "intensity": 0.5
  }
}
```

**Motion Control Parameters**:
- `camera`: `static`, `slow_zoom_in`, `slow_zoom_out`, `pan_left`, `pan_right`, `orbit_left`, `orbit_right`, `crane_up`, `crane_down`, `dolly_in`, `dolly_out`
- `intensity`: 0.0-1.0 (how aggressive the motion)

**Duration Options**: 5 seconds, 10 seconds (Gen-4 Turbo supports 10s natively)

**Prompt Structure Best Practices**:
- Lead with subject: "A woman in a red dress..."
- Add action: "...walking along a beach..."
- Add style/mood: "...golden hour lighting, cinematic color grading"
- Camera instruction: "...slow dolly tracking shot"

**Cost**: ~$0.50 per 5s clip (Gen-3), ~$0.75 per 5s clip (Gen-4 Turbo). Check current pricing.

---

### Kling AI

- **Base URL**: `https://api.klingai.com/v1`
- **Auth**: API key in header

**Video Generation**:
```
POST /v1/videos/generate
{
  "prompt": "Aerial drone shot of a futuristic city at sunset",
  "mode": "standard",
  "duration": 5,
  "aspect_ratio": "16:9"
}
```

**Quality/Speed Tradeoffs**:
- `mode: "turbo"` — fast generation (~60s), lower quality, good for iteration
- `mode: "standard"` — balanced (~3min), production-ready
- `mode: "professional"` — highest quality (~8min), best for final output

**Motion Presets**: `zoom_in`, `zoom_out`, `pan_left`, `pan_right`, `rotate_cw`, `rotate_ccw`, `static`

**Aspect Ratios**: `1:1`, `16:9`, `9:16`, `4:3`, `3:4`

---

### Pika Labs

- **Base URL**: `https://api.pika.art/v1`
- **Auth**: Bearer token

**Video Generation**:
```
POST /v1/generate
{
  "prompt": "A cat wearing sunglasses skateboarding in a neon city",
  "style": "cinematic",
  "motion_preset": "dynamic",
  "negative_prompt": "blurry, static, low quality",
  "duration": 4,
  "fps": 24,
  "resolution": "1080p"
}
```

**Style Controls**: `cinematic`, `anime`, `3d-animation`, `natural`, `watercolor`, `clay`

**Motion Presets**: `static`, `gentle`, `dynamic`, `dramatic`

**Prompt Best Practices**:
- Keep prompts concise (under 100 words)
- Specify camera movement explicitly: "camera slowly pans right"
- Include lighting: "warm golden hour", "cool blue moonlight"
- Avoid conflicting instructions (e.g., "static scene with fast action")

---

## FFmpeg Command Library (CRITICAL SECTION)

All commands assume FFmpeg 6.x+ installed. Test locally before deploying in automation.

### Concatenation

**Same Codec (fast, no re-encode)**:
```bash
# Create list.txt:
# file 'clip1.mp4'
# file 'clip2.mp4'
# file 'clip3.mp4'

ffmpeg -f concat -safe 0 -i list.txt -c copy output.mp4
```

**Different Codecs (re-encode to consistent settings)**:
```bash
ffmpeg -f concat -safe 0 -i list.txt \
  -c:v libx264 -preset medium -crf 23 \
  -c:a aac -b:a 192k \
  -movflags +faststart \
  output.mp4
```

**Concatenate with filter (when clips have different resolutions/framerates)**:
```bash
ffmpeg -i clip1.mp4 -i clip2.mp4 -i clip3.mp4 \
  -filter_complex \
  "[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[v0]; \
   [1:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[v1]; \
   [2:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30[v2]; \
   [v0][0:a][v1][1:a][v2][2:a]concat=n=3:v=1:a=1[outv][outa]" \
  -map "[outv]" -map "[outa]" \
  -c:v libx264 -preset medium -crf 23 \
  -c:a aac -b:a 192k \
  output.mp4
```

### Crossfade Transitions

**Crossfade between two clips (1 second transition)**:
```bash
ffmpeg -i clip1.mp4 -i clip2.mp4 \
  -filter_complex \
  "[0:v][1:v]xfade=transition=fade:duration=1:offset=4[outv]; \
   [0:a][1:a]acrossfade=d=1[outa]" \
  -map "[outv]" -map "[outa]" \
  -c:v libx264 -crf 23 -c:a aac output.mp4
```

**Available xfade transitions**: `fade`, `wipeleft`, `wiperight`, `wipeup`, `wipedown`, `slideleft`, `slideright`, `slideup`, `slidedown`, `circlecrop`, `rectcrop`, `distance`, `fadeblack`, `fadewhite`, `radial`, `smoothleft`, `smoothright`, `smoothup`, `smoothdown`, `circleopen`, `circleclose`, `dissolve`, `pixelize`, `diagtl`, `diagtr`, `diagbl`, `diagbr`

**Offset** = duration of first clip minus crossfade duration (e.g., 5s clip with 1s fade = offset 4)

### Background Music with Ducking

**Sidechain compress (duck music when voice is present)**:
```bash
ffmpeg -i video_with_voice.mp4 -i background_music.mp3 \
  -filter_complex \
  "[0:a]asplit=2[voice][sc]; \
   [1:a]volume=0.3[music]; \
   [music][sc]sidechaincompress=threshold=0.02:ratio=6:attack=200:release=1000[ducked]; \
   [voice][ducked]amix=inputs=2:duration=first[outa]" \
  -map 0:v -map "[outa]" \
  -c:v copy -c:a aac -b:a 192k output.mp4
```

**Simple volume mix (no ducking)**:
```bash
ffmpeg -i video.mp4 -i music.mp3 \
  -filter_complex \
  "[1:a]volume=0.15[bg]; \
   [0:a][bg]amix=inputs=2:duration=first:dropout_transition=2[outa]" \
  -map 0:v -map "[outa]" -c:v copy -c:a aac output.mp4
```

### Subtitles

**Burn-in SRT subtitles**:
```bash
ffmpeg -i input.mp4 -vf "subtitles=subs.srt:force_style='FontSize=24,FontName=Arial,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2,Shadow=1'" \
  -c:v libx264 -crf 23 -c:a copy output.mp4
```

**Burn-in ASS subtitles (preserves advanced styling)**:
```bash
ffmpeg -i input.mp4 -vf "ass=subs.ass" -c:v libx264 -crf 23 -c:a copy output.mp4
```

### Text Overlay (drawtext)

**Static text overlay**:
```bash
ffmpeg -i input.mp4 \
  -vf "drawtext=text='Hello World':fontsize=48:fontcolor=white:borderw=2:bordercolor=black:x=(w-tw)/2:y=h-th-50:fontfile=/path/to/font.ttf" \
  -c:v libx264 -crf 23 -c:a copy output.mp4
```

**Timed text overlay (show from 2s to 5s)**:
```bash
ffmpeg -i input.mp4 \
  -vf "drawtext=text='Limited Offer':fontsize=60:fontcolor=yellow:x=(w-tw)/2:y=(h-th)/2:enable='between(t,2,5)'" \
  -c:v libx264 -crf 23 -c:a copy output.mp4
```

### Speed Ramping

**Slow motion (0.5x speed)**:
```bash
ffmpeg -i input.mp4 -filter_complex "[0:v]setpts=2.0*PTS[v];[0:a]atempo=0.5[a]" \
  -map "[v]" -map "[a]" output.mp4
```

**Timelapse (4x speed)**:
```bash
ffmpeg -i input.mp4 -filter_complex "[0:v]setpts=0.25*PTS[v];[0:a]atempo=2.0,atempo=2.0[a]" \
  -map "[v]" -map "[a]" output.mp4
```

Note: `atempo` range is 0.5-2.0. Chain multiple for greater factors (e.g., 4x = `atempo=2.0,atempo=2.0`).

### Color Grading with LUTs

**Apply 3D LUT**:
```bash
ffmpeg -i input.mp4 -vf "lut3d=cinematic.cube" -c:v libx264 -crf 23 -c:a copy output.mp4
```

**Apply with intensity blending (50% LUT strength)**:
```bash
ffmpeg -i input.mp4 \
  -vf "split[original][tolut];[tolut]lut3d=cinematic.cube[luted];[original][luted]blend=all_expr='A*0.5+B*0.5'" \
  -c:v libx264 -crf 23 -c:a copy output.mp4
```

### Ken Burns Effect (Zoompan on Still Images)

**Slow zoom in on a still image (10 seconds, 1080p output)**:
```bash
ffmpeg -loop 1 -i photo.jpg -t 10 \
  -vf "zoompan=z='min(zoom+0.001,1.3)':d=300:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1920x1080:fps=30" \
  -c:v libx264 -crf 23 -pix_fmt yuv420p output.mp4
```

**Pan left to right (10 seconds)**:
```bash
ffmpeg -loop 1 -i photo.jpg -t 10 \
  -vf "zoompan=z='1.2':d=300:x='if(eq(on,1),0,x+2)':y='ih/2-(ih/zoom/2)':s=1920x1080:fps=30" \
  -c:v libx264 -crf 23 -pix_fmt yuv420p output.mp4
```

### Logo / Watermark Insertion

**Bottom-right corner with padding**:
```bash
ffmpeg -i input.mp4 -i logo.png \
  -filter_complex "[1:v]scale=120:-1[logo];[0:v][logo]overlay=W-w-20:H-h-20" \
  -c:v libx264 -crf 23 -c:a copy output.mp4
```

**Semi-transparent watermark**:
```bash
ffmpeg -i input.mp4 -i logo.png \
  -filter_complex "[1:v]format=rgba,colorchannelmixer=aa=0.3,scale=120:-1[logo];[0:v][logo]overlay=W-w-20:H-h-20" \
  -c:v libx264 -crf 23 -c:a copy output.mp4
```

**Position Reference**: `overlay=x:y` where `W`=main width, `H`=main height, `w`=overlay width, `h`=overlay height. Center: `(W-w)/2:(H-h)/2`. Top-left: `20:20`.

### Social Platform Export Presets

**Instagram Reels (1080x1920, H.264, 30fps, max 90s)**:
```bash
ffmpeg -i input.mp4 -t 90 \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,fps=30" \
  -c:v libx264 -preset slow -crf 20 -profile:v high -level 4.1 \
  -c:a aac -b:a 128k -ar 44100 \
  -movflags +faststart -pix_fmt yuv420p \
  instagram_reel.mp4
```

**TikTok (1080x1920, H.264, 30fps, max 180s)**:
```bash
ffmpeg -i input.mp4 -t 180 \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,fps=30" \
  -c:v libx264 -preset slow -crf 20 -profile:v high -level 4.1 \
  -c:a aac -b:a 128k -ar 44100 \
  -movflags +faststart -pix_fmt yuv420p \
  tiktok.mp4
```

**YouTube Shorts (1080x1920, H.264, 30fps, max 60s)**:
```bash
ffmpeg -i input.mp4 -t 60 \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,fps=30" \
  -c:v libx264 -preset slow -crf 18 -profile:v high -level 4.1 \
  -c:a aac -b:a 192k -ar 48000 \
  -movflags +faststart -pix_fmt yuv420p \
  youtube_short.mp4
```

**YouTube Long-form (1920x1080, H.264, 30fps, high bitrate)**:
```bash
ffmpeg -i input.mp4 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,fps=30" \
  -c:v libx264 -preset slow -crf 18 -profile:v high -level 4.2 \
  -b:v 12M -maxrate 15M -bufsize 25M \
  -c:a aac -b:a 320k -ar 48000 \
  -movflags +faststart -pix_fmt yuv420p \
  youtube_long.mp4
```

**X/Twitter (1920x1080 or 1280x720, H.264, max 140s)**:
```bash
ffmpeg -i input.mp4 -t 140 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,fps=30" \
  -c:v libx264 -preset slow -crf 22 -profile:v high -level 4.1 \
  -b:v 5M -maxrate 8M -bufsize 10M \
  -c:a aac -b:a 128k -ar 44100 \
  -movflags +faststart -pix_fmt yuv420p \
  twitter.mp4
```

### Batch Processing

**Process all MP4 files in a directory**:
```bash
for f in /path/to/clips/*.mp4; do
  ffmpeg -i "$f" -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2" \
    -c:v libx264 -crf 23 -c:a aac -b:a 128k \
    "/path/to/output/$(basename "$f" .mp4)_processed.mp4"
done
```

**Generate concat list from directory**:
```bash
for f in /path/to/clips/*.mp4; do
  echo "file '$f'" >> list.txt
done
ffmpeg -f concat -safe 0 -i list.txt -c copy final.mp4
```

### Hardware Acceleration

**NVIDIA NVENC (GPU encoding)**:
```bash
ffmpeg -hwaccel cuda -hwaccel_output_format cuda -i input.mp4 \
  -c:v h264_nvenc -preset p4 -cq 23 -c:a copy output.mp4
```

**Intel Quick Sync Video (QSV)**:
```bash
ffmpeg -hwaccel qsv -i input.mp4 \
  -c:v h264_qsv -global_quality 23 -c:a copy output.mp4
```

**Apple VideoToolbox (macOS)**:
```bash
ffmpeg -i input.mp4 \
  -c:v h264_videotoolbox -b:v 6M -c:a copy output.mp4
```

### Thumbnail Extraction

**Single thumbnail at specific time**:
```bash
ffmpeg -i input.mp4 -ss 00:00:05 -vframes 1 -q:v 2 thumbnail.jpg
```

**Multiple thumbnails (one per second)**:
```bash
ffmpeg -i input.mp4 -vf "fps=1" -q:v 2 thumb_%04d.jpg
```

**Grid/montage thumbnail (4x4)**:
```bash
ffmpeg -i input.mp4 -vf "select='not(mod(n,100))',scale=320:180,tile=4x4" -frames:v 1 montage.jpg
```

---

## Video Assembly Logic

### Scene Ordering and Pacing Rules

1. **Hook** (0-3 seconds): Strongest visual or statement first. Grab attention immediately.
2. **Context** (3-10 seconds): Establish the topic, show the product/subject.
3. **Body** (10-45 seconds): Alternate between talking head and B-roll every 5-8 seconds to maintain engagement.
4. **Climax** (45-55 seconds): Key benefit, demo, or transformation.
5. **CTA** (last 5-10 seconds): Call to action with text overlay.

**Pacing Guidelines**:
- Short-form (under 60s): Cut every 2-4 seconds
- Medium-form (1-5 min): Cut every 4-8 seconds
- Long-form (5+ min): Cut every 6-15 seconds
- Always cut on action or dialogue beats, not mid-sentence

### B-Roll Integration Patterns

- **Cutaway**: Main subject mentions a concept, cut to illustrative footage
- **Insert**: Close-up detail of what the subject is discussing
- **Overlay**: B-roll plays with voice-over audio continuing from main footage
- **Split-screen**: Main subject on one side, demonstration on the other
- Use 20-40% B-roll in talking-head content for visual variety

### Intro/Outro Templates

**Intro Template (3-5 seconds)**:
1. Brand logo animation (1-2s)
2. Title card with episode/topic name (1-2s)
3. Quick montage teaser of best moments (1-2s)

**Outro Template (5-10 seconds)**:
1. End card with subscribe/follow CTA
2. Related content thumbnails (YouTube end screen)
3. Social media handles and website
4. Background music fade out

### Lower Thirds and Graphics

**Lower third text overlay with background bar**:
```bash
ffmpeg -i input.mp4 \
  -vf "drawbox=x=0:y=ih*0.75:w=iw*0.4:h=60:color=black@0.7:t=fill, \
       drawtext=text='John Smith - CEO':fontsize=28:fontcolor=white:x=20:y=ih*0.75+10:fontfile=/path/to/font.ttf, \
       drawtext=text='Acme Corp':fontsize=20:fontcolor=0xCCCCCC:x=20:y=ih*0.75+35:fontfile=/path/to/font.ttf" \
  -c:v libx264 -crf 23 -c:a copy output.mp4
```

### Audio-Video Sync Verification

- **Check A/V offset**: `ffprobe -v error -show_entries stream=codec_type,start_time -of csv input.mp4`
- **Fix sync drift**: `ffmpeg -i input.mp4 -itsoffset 0.1 -i input.mp4 -map 0:v -map 1:a -c copy fixed.mp4` (adjusts audio by 100ms)
- **Visual check**: Use `ffplay` to preview before final export
- **Automated check**: Compare audio waveform peaks against video cut points

---

## Lip-Sync & Avatar Videos

### Higgsfield Speak v2 Detailed Workflow

1. **Prepare Audio**: Generate TTS (ElevenLabs recommended), ensure clean WAV/MP3
2. **Select Avatar**: Use pre-registered `avatar_id` or provide `presenter_photo_url`
3. **Submit Job**: POST to `/api/v1/speak/v2/generate`
4. **Poll Status**: GET `/api/v1/jobs/{job_id}/status` every 15s
5. **Download Output**: Retrieve video from `output_url`
6. **Post-Process**: Trim, color-correct, add overlays with FFmpeg

### Audio Requirements for Lip-Sync

- **Format**: WAV (preferred) or MP3
- **Sample Rate**: 16kHz minimum, 44.1kHz or 48kHz recommended
- **Channels**: Mono preferred for voice-only; stereo accepted
- **Duration**: 5-120 seconds per segment
- **Quality**: Clean recording, minimal background noise, no music
- **Normalization**: Normalize to -3dB peak before submission

### Avatar Selection and Customization

- **Pre-built avatars**: Use Higgsfield dashboard to browse and get `avatar_id`
- **Custom avatar from photo**: Provide front-facing, well-lit headshot (minimum 512x512)
- **Photo requirements**: Neutral expression, eyes open, face centered, solid or simple background
- **Avoid**: Sunglasses, hats covering forehead, extreme angles, group photos

### Natural Gesture Injection

- `gesture_mode: "natural"` — AI selects contextually appropriate gestures
- `gesture_mode: "expressive"` — more hand movement, head nods, emphasis gestures
- Best results with conversational tone audio (not monotone)
- For product demos, use `"minimal"` to keep focus on on-screen content

### Quality Validation Checks

1. **Lip sync accuracy**: Watch at 0.5x speed, check consonant sounds (p, b, m) match lip closure
2. **Eye contact**: Avatar should maintain natural eye line, no wandering gaze
3. **Head movement**: Should look natural, not robotic or jittery
4. **Audio alignment**: Ensure no delay between audio and lip movement
5. **Artifact detection**: Check for face distortion, texture flickering, or blending seams
6. **Resolution**: Output should match expected resolution (no unexpected downscaling)
