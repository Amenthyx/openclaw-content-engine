# Audio & Music Generation

Comprehensive reference for text-to-speech, voice cloning, music generation, and audio post-processing.

---

## Text-to-Speech

### ElevenLabs (PRIMARY)

#### API Endpoint
```
POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
Headers:
  xi-api-key: <API_KEY>
  Content-Type: application/json
  Accept: audio/mpeg  (or audio/wav, audio/pcm)
```

#### Request Payload
```json
{
  "text": "Hello, welcome to our product demo.",
  "model_id": "eleven_multilingual_v2",
  "voice_settings": {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.0,
    "use_speaker_boost": true
  },
  "output_format": "mp3_44100_128"
}
```

#### Voice Settings Parameters

| Parameter | Range | Description |
|-----------|-------|-------------|
| `stability` | 0.0-1.0 | Higher = more consistent, lower = more expressive/variable |
| `similarity_boost` | 0.0-1.0 | Higher = closer to original voice, lower = more creative |
| `style` | 0.0-1.0 | Style exaggeration (only multilingual v2). Higher = more dramatic |
| `use_speaker_boost` | bool | Enhances voice clarity, slight latency increase |

**Recommended starting values**: stability 0.5, similarity_boost 0.75, style 0.0

#### Models
- `eleven_multilingual_v2` — Best quality, 29 languages, recommended for most use cases
- `eleven_monolingual_v1` — English only, lower latency
- `eleven_turbo_v2` — Fastest, slightly lower quality, good for real-time

#### Output Formats
- `mp3_44100_128` — Standard MP3 (default)
- `mp3_44100_192` — Higher quality MP3
- `pcm_16000` — Raw PCM 16kHz (for further processing)
- `pcm_24000` — Raw PCM 24kHz
- `pcm_44100` — Raw PCM 44.1kHz
- `ulaw_8000` — Telephony format

#### Streaming Mode
```
POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream
```
Returns chunked audio as it generates. Use for real-time playback or long texts. Same payload as non-streaming.

#### Voice Selection
- **Browse voices**: `GET /v1/voices` returns all available voices with metadata
- **Get specific voice**: `GET /v1/voices/{voice_id}`
- **Popular voices**: Rachel (narrative), Adam (deep male), Bella (young female), Antoni (warm male)

#### Multi-Language Support
With `eleven_multilingual_v2`: English, Spanish, French, German, Italian, Portuguese, Polish, Hindi, Arabic, Japanese, Korean, Chinese, Dutch, Turkish, Swedish, Indonesian, Filipino, Malay, Romanian, Ukrainian, Greek, Czech, Danish, Finnish, Bulgarian, Croatian, Slovak, Tamil, and more.

Specify language by writing text in that language. The model auto-detects.

#### Cost Optimization
- Characters are billed per generation (including spaces and punctuation)
- Cache generated audio; do not re-generate identical text
- Use `eleven_turbo_v2` for drafts, `eleven_multilingual_v2` for final
- Batch similar voice generations to reduce API calls
- Monitor usage: `GET /v1/user/subscription`

---

### OpenAI TTS

#### Endpoint
```
POST https://api.openai.com/v1/audio/speech
Headers:
  Authorization: Bearer <API_KEY>
  Content-Type: application/json
```

#### Request Payload
```json
{
  "model": "tts-1-hd",
  "input": "Today we are launching our new product.",
  "voice": "nova",
  "response_format": "mp3",
  "speed": 1.0
}
```

#### Models
- `tts-1` — Optimized for speed, lower latency, slightly lower quality
- `tts-1-hd` — Optimized for quality, higher latency, better for final output

#### Voices
| Voice | Character |
|-------|-----------|
| `alloy` | Neutral, balanced |
| `echo` | Warm, conversational male |
| `fable` | Expressive, British-accented |
| `onyx` | Deep, authoritative male |
| `nova` | Friendly, energetic female |
| `shimmer` | Clear, professional female |

#### Speed Parameter
- Range: 0.25 to 4.0
- Default: 1.0
- Recommended: 0.9-1.1 for natural speech, 1.5-2.0 for podcast speedup

#### Output Formats
- `mp3` — Default, good compression
- `opus` — Best for streaming/low latency
- `aac` — Best for mobile/Apple devices
- `flac` — Lossless compression
- `wav` — Uncompressed, largest files
- `pcm` — Raw audio, no headers

Response is raw audio bytes. Save directly to file.

---

### Google Cloud TTS

#### Setup and Auth
1. Enable Cloud Text-to-Speech API in Google Cloud Console
2. Create a service account with TTS permissions
3. Download JSON key file
4. Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable

#### Endpoint
```
POST https://texttospeech.googleapis.com/v1/text:synthesize
Headers:
  Authorization: Bearer <ACCESS_TOKEN>
  Content-Type: application/json
```

#### Request Payload
```json
{
  "input": {
    "ssml": "<speak>Hello <break time='500ms'/> welcome to <emphasis level='strong'>our demo</emphasis></speak>"
  },
  "voice": {
    "languageCode": "en-US",
    "name": "en-US-Neural2-D",
    "ssmlGender": "MALE"
  },
  "audioConfig": {
    "audioEncoding": "MP3",
    "speakingRate": 1.0,
    "pitch": 0.0,
    "volumeGainDb": 0.0,
    "effectsProfileId": ["headphone-class-device"]
  }
}
```

Response contains base64-encoded audio in `audioContent` field.

#### Voice Tiers
- **Standard**: Basic synthesis, cheapest, robotic for long content
- **WaveNet**: Neural network voices, natural-sounding, 4x cost of Standard
- **Neural2**: Latest generation, best quality, same price as WaveNet
- **Studio**: Hand-tuned, limited languages, highest quality for supported locales

#### SSML Markup for Prosody Control
```xml
<speak>
  <!-- Pause -->
  <break time="750ms"/>

  <!-- Speed and pitch -->
  <prosody rate="slow" pitch="+2st">Important announcement</prosody>

  <!-- Emphasis -->
  <emphasis level="strong">critical update</emphasis>

  <!-- Say as (dates, numbers, etc.) -->
  <say-as interpret-as="date" format="mdy">3/6/2026</say-as>

  <!-- Substitution -->
  <sub alias="World Wide Web Consortium">W3C</sub>

  <!-- Whisper effect -->
  <amazon:effect name="whispered">this is a secret</amazon:effect>

  <!-- Paragraph and sentence breaks -->
  <p><s>First sentence.</s><s>Second sentence.</s></p>
</speak>
```

**Prosody rate values**: `x-slow`, `slow`, `medium`, `fast`, `x-fast`, or percentage like `80%`
**Prosody pitch values**: `x-low`, `low`, `medium`, `high`, `x-high`, or semitones like `+2st`, `-3st`

---

## Voice Cloning

### ElevenLabs Instant Voice Cloning

**Endpoint**: `POST https://api.elevenlabs.io/v1/voices/add`

```
Content-Type: multipart/form-data

Fields:
  name: "My Cloned Voice"
  description: "Professional male narrator"
  files: [audio_sample_1.mp3, audio_sample_2.mp3]
  labels: {"accent": "american", "gender": "male", "use_case": "narration"}
```

**Minimum**: 1 audio sample, at least 1 minute total
**Recommended**: 3-5 samples, 5-10 minutes total, diverse content (different sentences, emotions)
**Response**: Returns `voice_id` to use in TTS calls

### Professional Voice Cloning

- Minimum 30 minutes of high-quality audio
- Requires ElevenLabs professional tier subscription
- Submit through dashboard (not API)
- Training takes 1-4 hours
- Significantly better quality than instant cloning
- Fine-tuning iterations available

### Audio Quality Requirements for Training Samples

- **Format**: WAV or FLAC preferred (lossless); high-bitrate MP3 acceptable
- **Sample rate**: 44.1kHz or 48kHz
- **Bit depth**: 16-bit minimum, 24-bit preferred
- **Environment**: Quiet room, no echo, no background noise
- **Microphone**: Condenser mic recommended; avoid laptop/phone mics
- **Content**: Natural speech, varied sentences, avoid long pauses
- **Avoid**: Background music, sound effects, multiple speakers, whispering, shouting
- **Processing**: Do NOT apply compression, EQ, or effects before upload

### Legal Considerations

- Only clone voices you have explicit permission to clone
- Written consent from the voice owner is strongly recommended
- Some jurisdictions have specific voice likeness laws
- Commercial use of cloned voices may require additional licensing
- ElevenLabs TOS prohibits cloning public figures without consent
- Keep records of consent for compliance

---

## Music Generation

### Suno AI

#### API Endpoints and Auth
```
Base URL: https://api.suno.ai/v1
Auth: Bearer token in Authorization header
```

**Generate Music**:
```
POST /v1/generate
{
  "prompt": "upbeat electronic pop with synth bass, energetic drums, and female vocals singing about summer",
  "style": "electronic pop",
  "tempo": "fast",
  "duration": 30,
  "instrumental": false,
  "lyrics": "optional custom lyrics here"
}
```

**Check Status**:
```
GET /v1/generations/{generation_id}
```

#### Prompt Patterns for Genre/Mood/Tempo/Instruments

**Structure**: `[genre] [mood] [instruments] [vocal description] [topic/theme]`

**Examples**:
- Corporate: `"uplifting corporate background music, acoustic guitar, light piano, positive and inspiring, no vocals"`
- Epic: `"cinematic epic orchestral, full symphony, building crescendo, heroic and triumphant"`
- Chill: `"lo-fi hip hop beat, mellow piano chords, vinyl crackle, soft drums, relaxing study music"`
- Pop: `"catchy pop song, major key, acoustic guitar strumming, female vocals, upbeat and cheerful"`
- Dramatic: `"dark cinematic trailer music, deep bass, tension building, percussion hits, suspenseful"`

#### Custom Lyrics vs Instrumental
- Set `"instrumental": true` for background/ambient music
- Set `"instrumental": false` and provide `"lyrics"` for vocal tracks
- Lyrics format: Use line breaks for verses, `[Chorus]`, `[Verse]`, `[Bridge]` tags

#### Song Structure Control
```
[Intro]
(Gentle piano melody)

[Verse 1]
Walking through the morning light
Everything is feeling right

[Chorus]
This is where we belong
Singing our favorite song

[Bridge]
(Guitar solo, building energy)

[Outro]
(Fade out with piano)
```

#### Output
- Format: MP3 or WAV
- Duration: 30 seconds to 4 minutes
- Two variations generated per request (pick the best)

---

### Udio (Alternative)

#### API Comparison with Suno
- Similar prompt-based generation workflow
- Tends to produce more varied/experimental results
- Better at certain genres (rock, jazz, classical)
- Suno generally better at pop and electronic

#### Prompt Differences
- Udio responds well to more descriptive/narrative prompts
- Include reference artists for style guidance: "in the style of..." (for generation guidance, not replication)
- Udio handles complex time signatures and genre fusion better
- Shorter prompts (under 200 chars) often produce better results than long ones

---

## Audio Post-Processing (FFmpeg)

### Loudness Normalization

**YouTube standard (-14 LUFS)**:
```bash
ffmpeg -i input.mp3 -af "loudnorm=I=-14:LRA=11:TP=-1.0" -ar 48000 output.mp3
```

**Podcast standard (-16 LUFS)**:
```bash
ffmpeg -i input.mp3 -af "loudnorm=I=-16:LRA=11:TP=-1.5" -ar 44100 output.mp3
```

**Broadcast standard (-23 LUFS, EBU R128)**:
```bash
ffmpeg -i input.mp3 -af "loudnorm=I=-23:LRA=7:TP=-2.0" -ar 48000 output.mp3
```

**Two-pass normalization (more accurate)**:
```bash
# Pass 1: Measure
ffmpeg -i input.mp3 -af "loudnorm=I=-14:LRA=11:TP=-1.0:print_format=json" -f null /dev/null 2>&1 | grep -A 20 "Parsed_loudnorm"

# Pass 2: Apply (use measured values from pass 1)
ffmpeg -i input.mp3 -af "loudnorm=I=-14:LRA=11:TP=-1.0:measured_I=-18.5:measured_LRA=9.2:measured_TP=-0.3:measured_thresh=-29.1:offset=0.5:linear=true" output.mp3
```

### Remove Silence

**Remove silence from beginning and end**:
```bash
ffmpeg -i input.mp3 -af "silenceremove=start_periods=1:start_silence=0.5:start_threshold=-40dB:stop_periods=-1:stop_silence=0.5:stop_threshold=-40dB" output.mp3
```

**Parameters**:
- `start_periods=1` — Remove silence at the start (once)
- `stop_periods=-1` — Remove all trailing silence
- `start_silence=0.5` — Keep 0.5s of silence as buffer
- `start_threshold=-40dB` — Audio below this is "silence"

### Fade In / Fade Out

**Fade in (first 2 seconds)**:
```bash
ffmpeg -i input.mp3 -af "afade=t=in:st=0:d=2" output.mp3
```

**Fade out (last 3 seconds of a 60s clip)**:
```bash
ffmpeg -i input.mp3 -af "afade=t=out:st=57:d=3" output.mp3
```

**Both fades**:
```bash
ffmpeg -i input.mp3 -af "afade=t=in:st=0:d=2,afade=t=out:st=57:d=3" output.mp3
```

### Mix Voiceover with Background Music

**Simple mix with volume adjustment**:
```bash
ffmpeg -i voiceover.mp3 -i music.mp3 \
  -filter_complex "[1:a]volume=0.15[bg];[0:a][bg]amix=inputs=2:duration=first:dropout_transition=2[out]" \
  -map "[out]" -c:a aac -b:a 192k output.mp3
```

**Mix with fade-in/out on music**:
```bash
ffmpeg -i voiceover.mp3 -i music.mp3 \
  -filter_complex \
  "[1:a]volume=0.12,afade=t=in:st=0:d=2,afade=t=out:st=55:d=5[bg]; \
   [0:a][bg]amix=inputs=2:duration=first[out]" \
  -map "[out]" output.mp3
```

### Format Conversion

**WAV to MP3**:
```bash
ffmpeg -i input.wav -c:a libmp3lame -b:a 192k -ar 44100 output.mp3
```

**MP3 to AAC**:
```bash
ffmpeg -i input.mp3 -c:a aac -b:a 192k output.m4a
```

**Any format to WAV (uncompressed)**:
```bash
ffmpeg -i input.mp3 -c:a pcm_s16le -ar 44100 output.wav
```

**FLAC to MP3**:
```bash
ffmpeg -i input.flac -c:a libmp3lame -b:a 320k output.mp3
```

**Batch convert all WAV to MP3**:
```bash
for f in /path/to/*.wav; do
  ffmpeg -i "$f" -c:a libmp3lame -b:a 192k "${f%.wav}.mp3"
done
```

### Extract Audio from Video

**Extract as MP3**:
```bash
ffmpeg -i video.mp4 -vn -c:a libmp3lame -b:a 192k audio.mp3
```

**Extract as WAV (lossless)**:
```bash
ffmpeg -i video.mp4 -vn -c:a pcm_s16le -ar 44100 audio.wav
```

**Extract without re-encoding (copy codec)**:
```bash
ffmpeg -i video.mp4 -vn -c:a copy audio.aac
```

### Audio Compression and Limiting

**Dynamic range compression (make quiet parts louder)**:
```bash
ffmpeg -i input.mp3 -af "acompressor=threshold=-20dB:ratio=4:attack=5:release=50:makeup=2" output.mp3
```

**Hard limiter (prevent clipping)**:
```bash
ffmpeg -i input.mp3 -af "alimiter=limit=0.95:level=1:attack=5:release=50" output.mp3
```

**Broadcast-style processing chain (compress + limit + normalize)**:
```bash
ffmpeg -i input.mp3 -af \
  "acompressor=threshold=-24dB:ratio=3:attack=5:release=100:makeup=3, \
   alimiter=limit=0.95:level=1, \
   loudnorm=I=-16:LRA=11:TP=-1.5" \
  output.mp3
```

### Noise Reduction

**FFmpeg noise reduction (afftdn)**:
```bash
ffmpeg -i noisy_audio.mp3 -af "afftdn=nf=-25" cleaned.mp3
```

**Parameters**:
- `nf` (noise floor): dB level of noise to remove. `-25` is moderate, `-40` is aggressive
- `nt` (noise type): `w` (white), `v` (vinyl), `s` (shellac), `p` (custom profile)

**With noise profile (better results)**:
```bash
# Step 1: Extract a noise-only segment (e.g., first 2 seconds of silence)
ffmpeg -i noisy_audio.mp3 -ss 0 -t 2 noise_sample.wav

# Step 2: Apply noise reduction using the profile
ffmpeg -i noisy_audio.mp3 -af "afftdn=nf=-20:tn=enabled" cleaned.mp3
```

**High-pass filter (remove low rumble)**:
```bash
ffmpeg -i input.mp3 -af "highpass=f=80" output.mp3
```

**Combined noise reduction chain**:
```bash
ffmpeg -i noisy_audio.mp3 -af "highpass=f=80,afftdn=nf=-25,loudnorm=I=-16" cleaned_normalized.mp3
```

---

## Sound Effects

### Free SFX Sources and APIs

| Source | Access | Notes |
|--------|--------|-------|
| Freesound.org | API + web | Large library, Creative Commons, requires attribution for most |
| Pixabay Audio | Direct download | Free for commercial use, no attribution required |
| BBC Sound Effects | Web | Over 33,000 sounds, personal/educational use |
| Zapsplat | API + web | Free tier available, attribution required |
| Mixkit | Direct download | Free, no attribution |
| SoundBible | Direct download | Mix of CC and public domain |

**Freesound API**:
```
GET https://freesound.org/apiv2/search/text/?query=door+slam&token=<API_KEY>
```

### Categorization for Quick Retrieval

Organize SFX into standardized categories:
- **UI/UX**: click, hover, success, error, notification, swipe, toggle
- **Transitions**: whoosh, swoosh, impact, reveal, slide
- **Ambient**: city, nature, office, cafe, rain, wind
- **Human**: applause, laughter, gasp, footsteps, typing
- **Musical**: stinger, sting, hit, rise, drop, logo-sound
- **Mechanical**: button-press, switch, motor, beep, alarm

### Timing and Placement Best Practices

- **Transition sounds**: Place 2-5 frames before the visual transition for perceived sync
- **Impact sounds**: Align exactly with visual impact frame
- **Ambient beds**: Loop seamlessly, fade in/out over 1-2 seconds at scene boundaries
- **UI sounds**: Keep under 500ms, lower volume than speech (-20dB relative)
- **Music stingers**: Use at key moments (reveals, punchlines), keep 1-3 seconds
- **Layering**: Combine 2-3 subtle SFX for richer feel (e.g., whoosh + impact + reverb tail)
- **Volume hierarchy**: Speech > SFX > Music (typical ratio: 0dB / -12dB / -18dB relative)
