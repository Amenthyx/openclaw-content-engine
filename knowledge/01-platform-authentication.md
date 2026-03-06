# Platform Authentication & Session Management

Comprehensive reference for autonomous authentication, token management, rate limiting, and error recovery across all platforms used by OpenClaw's content engine.

---

## Higgsfield AI

### Auth Setup
Higgsfield uses dual-header API key authentication. No OAuth flow required.

### Base URL
```
https://platform.higgsfield.ai
```

### Required Headers
```
Content-Type: application/json
hf-api-key: <your-api-key>
hf-secret: <your-secret-key>
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Soul | POST | `/api/v1/soul/generate` | Text-to-image generation |
| DoP | POST | `/api/v1/dop/generate` | Image-to-video generation |
| Speak v2 | POST | `/api/v1/speak/v2/generate` | Lip-sync video generation |
| Status | GET | `/api/v1/jobs/{job_id}` | Poll job status |
| Result | GET | `/api/v1/jobs/{job_id}/result` | Retrieve completed output |

### Example: Soul Text-to-Image
```bash
curl -X POST https://platform.higgsfield.ai/api/v1/soul/generate \
  -H "Content-Type: application/json" \
  -H "hf-api-key: YOUR_API_KEY" \
  -H "hf-secret: YOUR_SECRET" \
  -d '{
    "prompt": "A professional product photo of a smartwatch on marble surface",
    "width": 1024,
    "height": 1024,
    "num_images": 1
  }'
```

### Rate Limits
- Approximate: 10 requests/minute for generation endpoints
- Poll endpoints: 60 requests/minute
- Backoff strategy: exponential with base 2s, max 60s

### Token Refresh
- API keys are long-lived; no refresh needed
- If 401 returned, re-validate keys in config
- No session keepalive required

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Invalid API key or secret | Verify both `hf-api-key` and `hf-secret` headers are present and correct |
| 429 | Rate limited | Wait for `Retry-After` header value, or exponential backoff starting at 5s |
| 503 | Service unavailable | Retry after 30s, max 3 retries |
| Job FAILED | Generation failed | Retry with simplified prompt; check payload format |

### Multi-Account Pattern
Store multiple key pairs in config array. Round-robin across accounts when rate limited on primary.

---

## OpenAI

### Auth Setup
API key authentication via Bearer token. Obtain keys from `platform.openai.com/api-keys`. Organization ID optional.

### Base URL
```
https://api.openai.com/v1
```

### Required Headers
```
Authorization: Bearer sk-...
Content-Type: application/json
OpenAI-Organization: org-... (optional)
OpenAI-Project: proj-... (optional)
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Chat Completions | POST | `/v1/chat/completions` | Text generation (GPT-4o, etc.) |
| Images (DALL-E 3) | POST | `/v1/images/generations` | Text-to-image |
| Images (gpt-image-1) | POST | `/v1/images/generations` | Advanced image generation |
| Image Edits | POST | `/v1/images/edits` | Inpainting / editing |
| TTS | POST | `/v1/audio/speech` | Text-to-speech |
| Transcription | POST | `/v1/audio/transcriptions` | Speech-to-text (Whisper) |
| Embeddings | POST | `/v1/embeddings` | Text embeddings |

### Example: DALL-E 3 Image Generation
```bash
curl -X POST https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-3",
    "prompt": "A minimalist product photo of wireless earbuds",
    "n": 1,
    "size": "1024x1024",
    "quality": "hd",
    "style": "natural"
  }'
```

### Example: gpt-image-1
```bash
curl -X POST https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-1",
    "prompt": "Product photography of a luxury watch",
    "n": 1,
    "size": "1024x1024",
    "quality": "high"
  }'
```

### Example: TTS
```bash
curl -X POST https://api.openai.com/v1/audio/speech \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tts-1-hd",
    "input": "Welcome to our product showcase.",
    "voice": "nova"
  }' --output speech.mp3
```

### Rate Limits (Tier-dependent)
| Tier | RPM (Chat) | TPM (Chat) | Images/min |
|------|-----------|-----------|------------|
| Tier 1 | 500 | 200,000 | 7 (DALL-E 3) |
| Tier 2 | 5,000 | 2,000,000 | 7 |
| Tier 3 | 5,000 | 10,000,000 | 7 |
| Tier 4+ | 10,000 | 30,000,000+ | 15 |

- Check response headers: `x-ratelimit-remaining-requests`, `x-ratelimit-remaining-tokens`
- Backoff: exponential starting at 1s, respect `Retry-After` header

### Token Refresh
- API keys are static; no refresh flow
- Project-scoped keys recommended for security
- Rotate keys periodically via dashboard

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Invalid API key | Check key validity, regenerate if expired |
| 429 | Rate limited | Exponential backoff; check `Retry-After` |
| 400 | Bad request / content policy | Modify prompt, check payload format |
| 500/503 | Server error | Retry after 5-10s, max 3 retries |
| `content_policy_violation` | Prompt flagged | Rephrase prompt avoiding flagged terms |

### Multi-Account Pattern
Use project-scoped API keys. Store multiple keys, rotate per-request or per-pipeline. Track usage per key via `x-ratelimit-*` headers.

---

## Runway ML

### Auth Setup
API key authentication via Bearer token or custom header. Obtain from Runway dashboard.

### Base URL
```
https://api.dev.runwayml.com/v1
```

### Required Headers
```
Authorization: Bearer rw_...
Content-Type: application/json
X-Runway-Version: 2024-11-06
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Image-to-Video | POST | `/image_to_video` | Gen-3/Gen-4 Turbo video generation |
| Task Status | GET | `/tasks/{task_id}` | Poll generation status |
| Text-to-Video | POST | `/text_to_video` | Text-driven video generation |

### Example: Image-to-Video (Gen-3 Turbo)
```bash
curl -X POST https://api.dev.runwayml.com/v1/image_to_video \
  -H "Authorization: Bearer rw_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Runway-Version: 2024-11-06" \
  -d '{
    "model": "gen3a_turbo",
    "promptImage": "https://example.com/image.jpg",
    "promptText": "Camera slowly zooms in on the product",
    "duration": 5,
    "ratio": "16:9"
  }'
```

### Rate Limits
- 6 concurrent generations per account
- ~100 requests/minute for polling
- Credits-based usage system
- Backoff: linear 10s intervals for polling, exponential for 429s

### Token Refresh
- API keys are long-lived, no refresh needed
- Regenerate from dashboard if compromised

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Invalid key | Verify key format starts with `rw_` |
| 422 | Invalid parameters | Check model name, image URL accessibility, duration |
| 429 | Rate limited | Wait, reduce concurrent jobs |
| FAILED task | Generation failed | Retry with different seed or simplified prompt |

---

## ElevenLabs

### Auth Setup
API key via custom header. Obtain from `elevenlabs.io/app/settings/api-keys`.

### Base URL
```
https://api.elevenlabs.io/v1
```

### Required Headers
```
xi-api-key: YOUR_API_KEY
Content-Type: application/json
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| TTS | POST | `/text-to-speech/{voice_id}` | Text-to-speech synthesis |
| TTS Streaming | POST | `/text-to-speech/{voice_id}/stream` | Streaming TTS |
| Voice Clone | POST | `/voices/add` | Instant voice clone |
| Voices List | GET | `/voices` | List available voices |
| Voice Settings | GET | `/voices/{voice_id}/settings` | Get voice parameters |
| Models | GET | `/models` | List available models |
| Sound Effects | POST | `/sound-generation` | AI sound effects |
| Speech-to-Speech | POST | `/speech-to-speech/{voice_id}` | Voice conversion |

### Example: Text-to-Speech
```bash
curl -X POST "https://api.elevenlabs.io/v1/text-to-speech/21m00Tcm4TlvDq8ikWAM" \
  -H "xi-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Welcome to our product showcase.",
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
      "stability": 0.5,
      "similarity_boost": 0.75,
      "style": 0.0,
      "use_speaker_boost": true
    }
  }' --output output.mp3
```

### Example: Instant Voice Clone
```bash
curl -X POST "https://api.elevenlabs.io/v1/voices/add" \
  -H "xi-api-key: YOUR_API_KEY" \
  -F "name=My Clone" \
  -F "files=@sample.mp3" \
  -F "description=Cloned voice for product narration"
```

### Rate Limits
| Plan | Characters/month | Concurrent requests |
|------|------------------|-------------------|
| Free | 10,000 | 2 |
| Starter | 30,000 | 3 |
| Creator | 100,000 | 5 |
| Pro | 500,000 | 10 |
| Scale | 2,000,000+ | 25 |

- Check `x-ratelimit-*` headers in responses
- Backoff: exponential starting at 2s

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Invalid API key | Regenerate key |
| 422 | Invalid voice_id or params | Verify voice_id via GET /voices |
| 429 | Rate/quota exceeded | Check character quota, upgrade or wait for reset |

---

## Stability AI

### Auth Setup
Bearer token authentication. Obtain from `platform.stability.ai/account/keys`.

### Base URL
```
https://api.stability.ai/v2beta
```

### Required Headers
```
Authorization: Bearer sk-...
Content-Type: application/json (or multipart/form-data for image inputs)
Accept: image/* (for direct image response) or application/json (for base64)
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| SD3 Generate | POST | `/stable-image/generate/sd3` | Stable Diffusion 3 generation |
| Ultra Generate | POST | `/stable-image/generate/ultra` | Ultra quality generation |
| Core Generate | POST | `/stable-image/generate/core` | Fast generation |
| Upscale | POST | `/stable-image/upscale/creative` | AI upscaling |
| Inpaint | POST | `/stable-image/edit/inpaint` | Masked inpainting |
| Outpaint | POST | `/stable-image/edit/outpaint` | Canvas extension |
| Remove BG | POST | `/stable-image/edit/remove-background` | Background removal |
| Search & Replace | POST | `/stable-image/edit/search-and-replace` | Object replacement |

### Example: SD3 Generation
```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/generate/sd3" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  -F "prompt=Professional product photography of a smartphone on clean white background" \
  -F "negative_prompt=blurry, low quality, distorted" \
  -F "aspect_ratio=1:1" \
  -F "model=sd3.5-large" \
  -F "output_format=png" \
  --output product.png
```

### Example: Background Removal
```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/edit/remove-background" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  -F "image=@product.jpg" \
  -F "output_format=png" \
  --output product_nobg.png
```

### Rate Limits
- 150 requests/10 seconds
- Credit-based billing per generation
- Backoff: exponential starting at 1s, respect `Retry-After`

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Invalid key | Check key format and validity |
| 402 | Insufficient credits | Top up credits |
| 403 | Content filtered | Modify prompt, avoid restricted content |
| 413 | Image too large | Resize input image below 10MP |
| 429 | Rate limited | Exponential backoff |

---

## Midjourney

### Auth Setup
Midjourney has **no official REST API**. Interaction is via Discord bot commands. For automation, use third-party API wrappers or Discord bot interaction.

### Discord Bot Interaction Pattern
```
Server: Midjourney Discord or private server with Midjourney bot
Channel: Any channel where the bot has access
Command: /imagine prompt:<your prompt>
```

### Unofficial API Wrappers
Several third-party services provide REST APIs that proxy Midjourney via Discord:
- GoAPI: `https://api.goapi.ai/mj/v2/imagine`
- UseAPI: `https://api.useapi.net/v2/jobs/imagine`

### Example: GoAPI Midjourney Proxy
```bash
curl -X POST "https://api.goapi.ai/mj/v2/imagine" \
  -H "X-API-Key: YOUR_GOAPI_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Professional product photography, studio lighting --ar 1:1 --v 6.1 --q 2",
    "process_mode": "fast"
  }'
```

### Command Structure
```
/imagine prompt: [subject] [style modifiers] [parameters]

Parameters:
--ar 16:9     Aspect ratio
--v 6.1       Model version
--q 2         Quality (0.25, 0.5, 1, 2)
--s 750       Stylize (0-1000)
--c 0         Chaos (0-100)
--no [thing]  Negative prompt
--seed 12345  Reproducibility
--style raw   Less Midjourney styling
```

### Rate Limits
- Basic: 3.3 jobs/hour (200/month)
- Standard: ~15 jobs/hour (unlimited relaxed)
- Pro: ~30 jobs/hour (unlimited)
- Concurrent: 3 fast jobs (Basic/Standard), 12 (Pro)

### Error Recovery
- "Job queued" timeout: re-submit after 10 minutes
- "Invalid parameter": check version compatibility
- Content moderation block: rephrase prompt

---

## Kling AI

### Auth Setup
API key authentication via AccessKey + SecretKey for JWT token generation.

### Base URL
```
https://api.klingai.com/v1
```

### Required Headers
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

### JWT Token Generation
Kling uses a JWT signed with your AccessKey and SecretKey (HMAC-SHA256). The JWT payload includes:
```json
{
  "iss": "<access_key>",
  "exp": <current_timestamp + 1800>,
  "nbf": <current_timestamp - 5>
}
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Text-to-Video | POST | `/videos/text2video` | Generate video from text |
| Image-to-Video | POST | `/videos/image2video` | Animate still image |
| Task Status | GET | `/videos/text2video/{task_id}` | Poll generation status |
| Text-to-Image | POST | `/images/generations` | Image generation |

### Example: Text-to-Video
```bash
curl -X POST "https://api.klingai.com/v1/videos/text2video" \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Product rotating on a display platform",
    "model_name": "kling-v1",
    "duration": "5",
    "aspect_ratio": "16:9",
    "mode": "std"
  }'
```

### Rate Limits
- Varies by subscription tier
- Typical: 10 concurrent generations
- Backoff: exponential from 5s

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | JWT expired or invalid | Regenerate JWT with fresh timestamps |
| 429 | Rate limited | Backoff and retry |
| FAILED | Content policy or generation error | Simplify prompt, check image URL |

---

## Suno AI

### Auth Setup
API key authentication. Obtain from Suno developer dashboard.

### Base URL
```
https://apibox.erweima.ai/api/v1 (third-party)
https://studio-api.suno.ai/api (official, limited access)
```

### Required Headers
```
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Generate Music | POST | `/generate` | Create music from description |
| Custom Generate | POST | `/generate/custom` | Generate with lyrics + style |
| Task Status | GET | `/generate/record/{task_id}` | Poll status |
| Extend | POST | `/generate/extend` | Extend existing track |

### Example: Music Generation
```bash
curl -X POST "https://apibox.erweima.ai/api/v1/generate" \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Upbeat electronic music for a tech product commercial, 30 seconds",
    "make_instrumental": true,
    "model": "chirp-v4"
  }'
```

### Rate Limits
- Free: 5 songs/day
- Pro: 500 songs/month
- API: typically 10 requests/minute
- Backoff: linear 10s intervals

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Invalid key | Verify API key |
| 429 | Quota exceeded | Wait for daily/monthly reset |
| 400 | Invalid prompt | Simplify description, check lyrics format |

---

## Pika Labs

### Auth Setup
API key authentication. Access via Pika's developer program.

### Base URL
```
https://api.pika.art/v1
```

### Required Headers
```
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Text-to-Video | POST | `/generate/text-to-video` | Video from text prompt |
| Image-to-Video | POST | `/generate/image-to-video` | Animate image |
| Status | GET | `/generations/{id}` | Poll status |

### Example: Text-to-Video
```bash
curl -X POST "https://api.pika.art/v1/generate/text-to-video" \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Smooth camera orbit around a product on a pedestal",
    "duration": 4,
    "aspect_ratio": "16:9",
    "model": "pika-2.0"
  }'
```

### Rate Limits
- Subscription-tier dependent
- Typical: 5-10 concurrent generations
- Backoff: exponential from 3s

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Auth failure | Regenerate API key |
| 429 | Rate limited | Exponential backoff |
| 400 | Bad prompt/params | Check model name, aspect ratio values |

---

## Dropbox

### Auth Setup
OAuth 2.0 with refresh tokens. Create app at `dropbox.com/developers/apps`.

### Base URLs
```
Auth: https://www.dropbox.com/oauth2/authorize
Token: https://api.dropboxapi.com/oauth2/token
API: https://api.dropboxapi.com/2
Content: https://content.dropboxapi.com/2
```

### OAuth2 Flow
1. **Authorization URL**:
```
https://www.dropbox.com/oauth2/authorize?client_id=APP_KEY&response_type=code&token_access_type=offline
```
2. **Exchange code for tokens**:
```bash
curl -X POST https://api.dropboxapi.com/oauth2/token \
  -d "code=AUTH_CODE" \
  -d "grant_type=authorization_code" \
  -d "client_id=APP_KEY" \
  -d "client_secret=APP_SECRET"
```
3. **Response** includes `access_token` (short-lived, ~4 hours) and `refresh_token` (long-lived).

### Token Refresh
```bash
curl -X POST https://api.dropboxapi.com/oauth2/token \
  -d "grant_type=refresh_token" \
  -d "refresh_token=REFRESH_TOKEN" \
  -d "client_id=APP_KEY" \
  -d "client_secret=APP_SECRET"
```

### Required Headers
```
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Upload | POST | `content://files/upload` | Upload files (<150MB) |
| Upload Session | POST | `content://files/upload_session/start` | Large file upload |
| Download | POST | `content://files/download` | Download file |
| Create Shared Link | POST | `api://sharing/create_shared_link_with_settings` | Get shareable URL |
| List Folder | POST | `api://files/list_folder` | List directory contents |
| Get Metadata | POST | `api://files/get_metadata` | File metadata |
| Delete | POST | `api://files/delete_v2` | Delete file/folder |

### Example: Upload File
```bash
curl -X POST https://content.dropboxapi.com/2/files/upload \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Dropbox-API-Arg: {\"path\": \"/output/video.mp4\", \"mode\": \"overwrite\"}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @video.mp4
```

### Example: Create Shared Link
```bash
curl -X POST https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"path": "/output/video.mp4", "settings": {"requested_visibility": "public"}}'
```

### Rate Limits
- 12,000 calls/app/15 minutes for non-upload endpoints
- Upload: 1,000 calls/15 minutes
- Backoff: exponential, respect `Retry-After` header (seconds)

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Expired token | Refresh using refresh_token |
| 409 | Path conflict | Check path, use `mode: overwrite` |
| 429 | Rate limited | Wait for `Retry-After` duration |

---

## Google Drive

### Auth Setup
OAuth 2.0 with service account or user consent. Create credentials at `console.cloud.google.com`.

### Base URL
```
https://www.googleapis.com/drive/v3
https://www.googleapis.com/upload/drive/v3 (for uploads)
```

### OAuth2 Flow
1. **Authorization URL**:
```
https://accounts.google.com/o/oauth2/v2/auth?client_id=CLIENT_ID&redirect_uri=REDIRECT&response_type=code&scope=https://www.googleapis.com/auth/drive.file&access_type=offline
```
2. **Exchange code**:
```bash
curl -X POST https://oauth2.googleapis.com/token \
  -d "code=AUTH_CODE" \
  -d "client_id=CLIENT_ID" \
  -d "client_secret=CLIENT_SECRET" \
  -d "redirect_uri=REDIRECT" \
  -d "grant_type=authorization_code"
```

### Token Refresh
```bash
curl -X POST https://oauth2.googleapis.com/token \
  -d "grant_type=refresh_token" \
  -d "refresh_token=REFRESH_TOKEN" \
  -d "client_id=CLIENT_ID" \
  -d "client_secret=CLIENT_SECRET"
```
Access tokens expire in 3600 seconds (1 hour).

### Required Headers
```
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Upload | POST | `/upload/drive/v3/files?uploadType=multipart` | Upload file |
| Resumable Upload | POST | `/upload/drive/v3/files?uploadType=resumable` | Large uploads |
| List Files | GET | `/drive/v3/files` | Search/list files |
| Get File | GET | `/drive/v3/files/{fileId}` | File metadata |
| Download | GET | `/drive/v3/files/{fileId}?alt=media` | Download content |
| Delete | DELETE | `/drive/v3/files/{fileId}` | Delete file |
| Permissions | POST | `/drive/v3/files/{fileId}/permissions` | Share file |

### Rate Limits
- 20,000 queries/100 seconds/project
- 20 queries/100 seconds/user
- Uploads: 750 GB/day per user
- Backoff: exponential with jitter, starting at 1s

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Token expired | Refresh token |
| 403 | Quota exceeded or insufficient permissions | Check scopes, wait for quota reset |
| 404 | File not found | Verify file ID |
| 429 | Rate limited | Exponential backoff with jitter |

---

## YouTube Data API

### Auth Setup
OAuth 2.0 required for video uploads. API key sufficient for read-only operations. Enable YouTube Data API v3 in Google Cloud Console.

### Base URL
```
https://www.googleapis.com/youtube/v3
https://www.googleapis.com/upload/youtube/v3 (uploads)
```

### OAuth2 Scopes
```
https://www.googleapis.com/auth/youtube.upload
https://www.googleapis.com/auth/youtube
https://www.googleapis.com/auth/youtube.force-ssl
```

### Key Endpoints
| Service | Method | Endpoint | Purpose |
|---------|--------|----------|---------|
| Upload Video | POST | `/upload/youtube/v3/videos?uploadType=resumable` | Upload video |
| Update Video | PUT | `/youtube/v3/videos` | Update metadata |
| Set Thumbnail | POST | `/upload/youtube/v3/thumbnails/set` | Custom thumbnail |
| List Videos | GET | `/youtube/v3/videos` | Get video details |
| Channels | GET | `/youtube/v3/channels` | Channel info |

### Example: Initiate Resumable Upload
```bash
curl -X POST "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "snippet": {
      "title": "Product Showcase",
      "description": "Automated promo video",
      "tags": ["product", "promo"],
      "categoryId": "22"
    },
    "status": {
      "privacyStatus": "private",
      "selfDeclaredMadeForKids": false
    }
  }'
```
Response includes `Location` header with upload URI. PUT video bytes to that URI.

### Rate Limits
- 10,000 quota units/day (default)
- Video upload: 1,600 units per upload
- List operations: 1-3 units each
- Backoff: exponential, respect `Retry-After`

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Auth expired | Refresh OAuth token |
| 403 `quotaExceeded` | Daily quota hit | Wait 24h or request quota increase |
| 400 `uploadLimitExceeded` | Too many uploads | Wait 24h |
| 403 `forbidden` | Channel not verified | Verify channel for uploads > 15 min |

---

## Instagram Graph API

### Auth Setup
Requires Meta Business account. App created at `developers.facebook.com`. Uses Facebook OAuth with Instagram permissions.

### Base URL
```
https://graph.facebook.com/v19.0
```

### OAuth2 Flow
1. **Login URL**:
```
https://www.facebook.com/v19.0/dialog/oauth?client_id=APP_ID&redirect_uri=REDIRECT&scope=instagram_basic,instagram_content_publish,pages_show_list,pages_read_engagement
```
2. **Exchange code for short-lived token**:
```bash
curl -X GET "https://graph.facebook.com/v19.0/oauth/access_token?client_id=APP_ID&redirect_uri=REDIRECT&client_secret=APP_SECRET&code=CODE"
```
3. **Exchange for long-lived token (60 days)**:
```bash
curl -X GET "https://graph.facebook.com/v19.0/oauth/access_token?grant_type=fb_exchange_token&client_id=APP_ID&client_secret=APP_SECRET&fb_exchange_token=SHORT_TOKEN"
```

### Token Refresh
Long-lived tokens can be refreshed before expiry:
```bash
curl -X GET "https://graph.facebook.com/v19.0/oauth/access_token?grant_type=fb_exchange_token&client_id=APP_ID&client_secret=APP_SECRET&fb_exchange_token=CURRENT_LONG_TOKEN"
```

### Media Publish Flow (2-step)
**Step 1: Create media container**
```bash
curl -X POST "https://graph.facebook.com/v19.0/{ig_user_id}/media" \
  -d "image_url=https://example.com/image.jpg" \
  -d "caption=Check out our new product! #launch" \
  -d "access_token=TOKEN"
```

**Step 2: Publish container**
```bash
curl -X POST "https://graph.facebook.com/v19.0/{ig_user_id}/media_publish" \
  -d "creation_id=CONTAINER_ID" \
  -d "access_token=TOKEN"
```

### Reels Upload (video)
```bash
# Step 1: Create container
curl -X POST "https://graph.facebook.com/v19.0/{ig_user_id}/media" \
  -d "media_type=REELS" \
  -d "video_url=https://example.com/video.mp4" \
  -d "caption=Product reveal!" \
  -d "access_token=TOKEN"

# Step 2: Poll status until FINISHED
curl -X GET "https://graph.facebook.com/v19.0/{container_id}?fields=status_code&access_token=TOKEN"

# Step 3: Publish
curl -X POST "https://graph.facebook.com/v19.0/{ig_user_id}/media_publish" \
  -d "creation_id=CONTAINER_ID" \
  -d "access_token=TOKEN"
```

### Rate Limits
- 200 calls/user/hour (Graph API general)
- 25 posts/day per Instagram account
- Reels: subject to additional review delays
- Backoff: exponential, check `x-business-use-case-usage` header

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 190 | Token expired | Refresh long-lived token |
| 4 | Rate limited | Exponential backoff |
| 36003 | Media not ready | Poll status_code until FINISHED |
| 2207026 | Invalid media | Check URL accessibility, format support |

---

## TikTok Content Posting API

### Auth Setup
OAuth 2.0 via TikTok for Developers. Requires approved app with `video.publish` scope.

### Base URL
```
https://open.tiktokapis.com/v2
```

### OAuth2 Flow
1. **Authorization**:
```
https://www.tiktok.com/v2/auth/authorize/?client_key=CLIENT_KEY&scope=user.info.basic,video.publish&response_type=code&redirect_uri=REDIRECT
```
2. **Token exchange**:
```bash
curl -X POST "https://open.tiktokapis.com/v2/oauth/token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_key=KEY&client_secret=SECRET&code=CODE&grant_type=authorization_code&redirect_uri=REDIRECT"
```

### Token Refresh
Access tokens expire in 86400s (24 hours). Refresh tokens valid for 365 days.
```bash
curl -X POST "https://open.tiktokapis.com/v2/oauth/token/" \
  -d "client_key=KEY&client_secret=SECRET&grant_type=refresh_token&refresh_token=REFRESH_TOKEN"
```

### Video Publish Flow
**Step 1: Init upload**
```bash
curl -X POST "https://open.tiktokapis.com/v2/post/publish/video/init/" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "post_info": {
      "title": "Product Launch",
      "privacy_level": "SELF_ONLY",
      "disable_duet": false,
      "disable_comment": false,
      "disable_stitch": false
    },
    "source_info": {
      "source": "PULL_FROM_URL",
      "video_url": "https://example.com/video.mp4"
    }
  }'
```

### Rate Limits
- Video publish: varies by app approval level
- General API: 600 requests/minute
- Backoff: exponential from 1s

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| `access_token_invalid` | Token expired | Refresh token |
| `spam_risk_too_many_posts` | Post limit reached | Wait 24h |
| `video_file_error` | Invalid video format | Ensure MP4, H.264, AAC, min 3s |

---

## X / Twitter

### Auth Setup
OAuth 2.0 with PKCE (user context) or App-only Bearer Token. Create app at `developer.x.com`.

### Base URL
```
https://api.x.com/2 (v2 API)
https://upload.twitter.com/1.1 (media uploads still v1.1)
```

### OAuth 2.0 PKCE Flow
1. **Authorization**:
```
https://twitter.com/i/oauth2/authorize?response_type=code&client_id=CLIENT_ID&redirect_uri=REDIRECT&scope=tweet.read%20tweet.write%20users.read%20offline.access&state=STATE&code_challenge=CHALLENGE&code_challenge_method=S256
```
2. **Token exchange**:
```bash
curl -X POST "https://api.x.com/2/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "code=CODE&grant_type=authorization_code&client_id=CLIENT_ID&redirect_uri=REDIRECT&code_verifier=VERIFIER"
```

### Token Refresh
Access tokens expire in 2 hours. Refresh tokens valid until revoked.
```bash
curl -X POST "https://api.x.com/2/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=REFRESH_TOKEN&client_id=CLIENT_ID"
```

### Media Upload + Tweet Flow
**Step 1: Upload media (v1.1, chunked for video)**
```bash
# INIT
curl -X POST "https://upload.twitter.com/1.1/media/upload.json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d "command=INIT&total_bytes=FILE_SIZE&media_type=video/mp4&media_category=tweet_video"

# APPEND (repeat for each chunk)
curl -X POST "https://upload.twitter.com/1.1/media/upload.json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -F "command=APPEND" \
  -F "media_id=MEDIA_ID" \
  -F "segment_index=0" \
  -F "media_data=BASE64_CHUNK"

# FINALIZE
curl -X POST "https://upload.twitter.com/1.1/media/upload.json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d "command=FINALIZE&media_id=MEDIA_ID"

# STATUS (poll until processing_info.state == "succeeded")
curl -X GET "https://upload.twitter.com/1.1/media/upload.json?command=STATUS&media_id=MEDIA_ID" \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

**Step 2: Create tweet with media**
```bash
curl -X POST "https://api.x.com/2/tweets" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Check out our latest product!",
    "media": {"media_ids": ["MEDIA_ID"]}
  }'
```

### Rate Limits (v2)
| Endpoint | Free | Basic | Pro |
|----------|------|-------|-----|
| POST tweets | 1,500/month | 3,000/month | 300,000/month |
| GET tweets | 1 req/15min | 10,000/month | 1,000,000/month |
| Media upload | 415 uploads/15min | Same | Same |

- Check `x-rate-limit-remaining` and `x-rate-limit-reset` headers
- Backoff: exponential from 1s, max 5 min

### Common Errors & Recovery
| Error Code | Meaning | Recovery |
|------------|---------|----------|
| 401 | Token expired | Refresh using refresh_token |
| 403 | Forbidden (scope/access) | Check app permissions and scopes |
| 429 | Rate limited | Wait until `x-rate-limit-reset` timestamp |
| `duplicate_content` | Same tweet text | Modify text slightly |

---

## Token Storage Strategy

### Secure Storage Principles
1. **Never store tokens in code or version control** -- use environment variables or encrypted config files
2. **Separate secrets from config** -- keep `config.local.json` (gitignored) for real keys, `config-template.json` (tracked) for structure
3. **Encrypt at rest** -- use OS keychain, HashiCorp Vault, or encrypted SQLite for token storage

### Storage Architecture
```
token_store/
  platform_tokens.encrypted.db   (SQLite, AES-256 encrypted)

Schema:
  platform TEXT PRIMARY KEY,
  access_token TEXT,
  refresh_token TEXT,
  expires_at INTEGER,
  metadata JSON,
  updated_at TIMESTAMP
```

### Token Rotation Pattern
```python
async def get_valid_token(platform: str) -> str:
    token = token_store.get(platform)
    if token.expires_at < now() + buffer_seconds(300):
        new_token = await refresh_token(platform, token.refresh_token)
        token_store.update(platform, new_token)
        return new_token.access_token
    return token.access_token
```

### Per-Platform Token Lifetimes
| Platform | Access Token TTL | Refresh Token TTL | Auto-Refresh |
|----------|-----------------|-------------------|--------------|
| Higgsfield | Permanent (API key) | N/A | No |
| OpenAI | Permanent (API key) | N/A | No |
| Runway | Permanent (API key) | N/A | No |
| ElevenLabs | Permanent (API key) | N/A | No |
| Stability | Permanent (API key) | N/A | No |
| Kling | 30 min (JWT) | N/A (regenerate) | Yes |
| Dropbox | 4 hours | Permanent | Yes |
| Google (Drive/YouTube) | 1 hour | Permanent | Yes |
| Instagram (Meta) | 60 days | Refresh before expiry | Yes |
| TikTok | 24 hours | 365 days | Yes |
| X/Twitter | 2 hours | Permanent (until revoked) | Yes |

---

## Unified Auth Middleware

### Pattern: Retry + Refresh Wrapper
Every platform call should pass through a middleware that handles:
1. Token validation and refresh before request
2. Retry with exponential backoff on transient errors
3. Token refresh on 401 responses
4. Rate limit handling on 429 responses

### Pseudocode Implementation
```python
class AuthMiddleware:
    def __init__(self, token_store, max_retries=3):
        self.token_store = token_store
        self.max_retries = max_retries

    async def request(self, platform: str, method: str, url: str, **kwargs):
        for attempt in range(self.max_retries):
            token = await self.get_valid_token(platform)
            headers = self.build_headers(platform, token)

            response = await http_client.request(method, url, headers=headers, **kwargs)

            if response.status == 200:
                return response
            elif response.status == 401:
                await self.force_refresh(platform)
                continue
            elif response.status == 429:
                retry_after = self.get_retry_delay(response, attempt)
                await sleep(retry_after)
                continue
            elif response.status >= 500:
                await sleep(2 ** attempt)
                continue
            else:
                raise PlatformError(platform, response.status, response.body)

        raise MaxRetriesExceeded(platform, url)

    def build_headers(self, platform, token):
        HEADER_FORMATS = {
            "openai": {"Authorization": f"Bearer {token}"},
            "stability": {"Authorization": f"Bearer {token}"},
            "elevenlabs": {"xi-api-key": token},
            "higgsfield": {"hf-api-key": token["api_key"], "hf-secret": token["secret"]},
            "runway": {"Authorization": f"Bearer {token}"},
            "dropbox": {"Authorization": f"Bearer {token}"},
            "google": {"Authorization": f"Bearer {token}"},
            "tiktok": {"Authorization": f"Bearer {token}"},
            "twitter": {"Authorization": f"Bearer {token}"},
            "instagram": {},  # token passed as query param
        }
        return {**HEADER_FORMATS.get(platform, {}), "Content-Type": "application/json"}

    def get_retry_delay(self, response, attempt):
        retry_after = response.headers.get("Retry-After")
        if retry_after:
            return int(retry_after)
        return min(2 ** attempt * 2, 60)
```

---

## Health Check Patterns

### Pre-Pipeline Verification
Before starting any content pipeline, verify all required platforms are accessible.

### Per-Platform Health Checks
```python
HEALTH_CHECKS = {
    "openai": {
        "method": "GET",
        "url": "https://api.openai.com/v1/models",
        "expect": 200,
        "timeout": 10
    },
    "elevenlabs": {
        "method": "GET",
        "url": "https://api.elevenlabs.io/v1/voices",
        "expect": 200,
        "timeout": 10
    },
    "stability": {
        "method": "GET",
        "url": "https://api.stability.ai/v1/engines/list",
        "expect": 200,
        "timeout": 10
    },
    "dropbox": {
        "method": "POST",
        "url": "https://api.dropboxapi.com/2/check/user",
        "body": {"query": "ping"},
        "expect": 200,
        "timeout": 10
    },
    "higgsfield": {
        "method": "GET",
        "url": "https://platform.higgsfield.ai/api/v1/health",
        "expect": 200,
        "timeout": 10
    },
    "runway": {
        "method": "GET",
        "url": "https://api.dev.runwayml.com/v1/tasks?limit=1",
        "expect": 200,
        "timeout": 10
    }
}

async def verify_platforms(required_platforms: list[str]) -> dict:
    results = {}
    for platform in required_platforms:
        check = HEALTH_CHECKS[platform]
        try:
            token = await get_valid_token(platform)
            headers = build_headers(platform, token)
            response = await http_client.request(
                check["method"], check["url"],
                headers=headers,
                timeout=check["timeout"]
            )
            results[platform] = {
                "status": "healthy" if response.status == check["expect"] else "degraded",
                "latency_ms": response.elapsed_ms,
                "quota_remaining": parse_quota_headers(response)
            }
        except Exception as e:
            results[platform] = {"status": "unreachable", "error": str(e)}
    return results
```

### Pipeline Gate
```python
async def pipeline_preflight(pipeline_config):
    required = pipeline_config["platforms"]
    health = await verify_platforms(required)

    failed = [p for p, h in health.items() if h["status"] == "unreachable"]
    if failed:
        raise PipelineAbort(f"Required platforms unreachable: {failed}")

    degraded = [p for p, h in health.items() if h["status"] == "degraded"]
    if degraded:
        log.warning(f"Degraded platforms (proceeding with caution): {degraded}")

    return health
```

### Continuous Monitoring
For long-running pipelines, re-check platform health between major stages:
- After image generation, before video generation
- After video generation, before upload/publish
- Before each social media post in multi-platform distribution

This prevents wasted compute on upstream stages when a downstream platform becomes unavailable mid-pipeline.
