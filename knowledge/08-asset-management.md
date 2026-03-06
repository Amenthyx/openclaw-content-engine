# Asset Management

## File Naming Conventions

### Standard Pattern
```
{project}_{platform}_{type}_{variant}_{date}.{ext}
```

### Examples
```
brandx_instagram_reel_v1_20260306.mp4
brandx_instagram_carousel_slide1_20260306.png
brandx_youtube_thumb_a_20260306.png
brandx_youtube_thumb_b_20260306.png
brandx_tiktok_music_bg_20260306.mp3
brandx_twitter_banner_v2_20260306.png
brandx_universal_logo_dark_20260306.svg
```

### Naming Rules
- All lowercase, underscores as separators
- No spaces, special characters, or accented characters
- Date format: YYYYMMDD
- Variant: `v1`, `v2` for versions; `a`, `b` for A/B tests; `slide1`, `slide2` for sequences
- Keep filenames under 100 characters total
- Platform codes: `instagram`, `tiktok`, `youtube`, `twitter`, `linkedin`, `universal`
- Type codes: `reel`, `post`, `story`, `thumb`, `banner`, `carousel`, `ad`, `music`, `sfx`, `vo`

---

## Folder Structure

```
/projects/{project_name}/
├── input/                  # Source materials provided by client or team
│   ├── images/            # Product photos, logos, brand assets
│   ├── audio/             # Voiceovers, music tracks, sound effects
│   ├── video/             # Raw footage, B-roll, screen recordings
│   └── docs/              # Scripts, briefs, brand guidelines, references
├── generated/              # AI-generated assets (not yet processed)
│   ├── images/            # Generated images (DALL-E, MJ, SD, Flux)
│   ├── video/             # Generated video clips (Runway, Higgsfield, Kling)
│   ├── audio/             # Generated audio/music (ElevenLabs, Suno)
│   └── avatars/           # Generated avatar frames and lip-sync outputs
├── intermediate/           # Processing intermediates (can be cleaned up)
│   ├── scenes/            # Individual scene clips ready for merge
│   ├── composites/        # Merged but unfinished compositions
│   └── temp/              # Temporary processing files (auto-cleanup target)
├── output/                 # Final deliverables ready for publishing
│   ├── instagram/         # Instagram-specific exports (reels, posts, stories)
│   ├── tiktok/            # TikTok-specific exports
│   ├── youtube/           # YouTube-specific exports (videos, thumbnails)
│   ├── twitter/           # X/Twitter-specific exports
│   ├── linkedin/          # LinkedIn-specific exports
│   └── universal/         # Master/archive quality (highest resolution)
├── metadata/               # Tracking data and pipeline logs
│   ├── manifest.json      # Asset manifest with all file metadata
│   ├── prompts.json       # Prompts used for each generation
│   └── pipeline.json      # Pipeline execution log with timestamps
└── brand/                  # Brand guidelines and identity assets
    ├── colors.json        # Color palette (hex, RGB, CMYK values)
    ├── fonts/             # Brand fonts (TTF/OTF files)
    ├── logos/             # Logo variants (full, icon, dark, light, mono)
    └── guidelines.md      # Brand voice and visual guidelines document
```

### Directory Management Rules
- Create project directory on first pipeline run
- Never delete `input/` or `brand/` contents automatically
- `intermediate/temp/` can be auto-cleaned after pipeline completes
- `generated/` preserves all AI outputs for reference and reuse
- `output/` contains only final, approved deliverables

---

## Asset Manifest Schema

```json
{
  "id": "uuid-v4-string",
  "project": "project_name",
  "filename": "brandx_instagram_reel_v1_20260306.mp4",
  "path": "output/instagram/brandx_instagram_reel_v1_20260306.mp4",
  "type": "video",
  "subtype": "reel",
  "platform": "instagram",
  "dimensions": {
    "width": 1080,
    "height": 1920
  },
  "duration": 30.5,
  "fileSize": 15728640,
  "format": "mp4",
  "codec": "h264",
  "bitrate": "8000k",
  "fps": 30,
  "createdAt": "2026-03-06T12:00:00Z",
  "updatedAt": "2026-03-06T14:30:00Z",
  "source": "higgsfield",
  "prompt": "the generation prompt used to create this asset",
  "model": "higgsfield-soul-v2",
  "parentId": "uuid-of-source-asset-if-derived",
  "childIds": ["uuid-of-derived-assets"],
  "tags": ["product", "promo", "v1", "approved"],
  "status": "draft",
  "score": null,
  "publishedTo": [
    {
      "platform": "instagram",
      "url": "https://instagram.com/p/...",
      "publishedAt": "2026-03-07T09:00:00Z",
      "postId": "platform-specific-post-id"
    }
  ],
  "analytics": {
    "reach": null,
    "engagement": null,
    "lastUpdated": null
  }
}
```

### Status Values
- `draft` — freshly generated, not reviewed
- `review` — submitted for review/approval
- `approved` — approved for publishing
- `published` — live on one or more platforms
- `archived` — no longer active, kept for reference
- `rejected` — did not pass review, tagged with rejection reason

### Manifest Operations
- **Create**: auto-generate on asset creation, populate metadata from file
- **Update**: update status, tags, analytics on state changes
- **Query**: filter by status, platform, type, date range, tags
- **Export**: generate CSV/JSON report of all assets matching criteria
- **Prune**: remove entries for deleted files, archive old entries

---

## Cloud Storage Patterns

### Dropbox

**Upload:**
```
POST https://content.dropboxapi.com/2/files/upload
Headers:
  Authorization: Bearer {access_token}
  Dropbox-API-Arg: {"path": "/projects/brandx/output/reel.mp4", "mode": "add"}
  Content-Type: application/octet-stream
Body: [file binary]
```

**Download:**
```
POST https://api.dropboxapi.com/2/files/download
Headers:
  Authorization: Bearer {access_token}
  Dropbox-API-Arg: {"path": "/projects/brandx/output/reel.mp4"}
```

**Create Shared Link:**
```
POST https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings
Body: {
  "path": "/projects/brandx/output/reel.mp4",
  "settings": {"requested_visibility": "public", "access": "viewer"}
}
```

**Batch Upload:** Use `/2/files/upload_session/start`, `/append`, `/finish_batch` for multiple files.

**Direct Download URL:** Replace `dl=0` with `dl=1` in shared links for direct file access.

### S3 / Cloudflare R2

**Multipart Upload for Large Files (>100MB):**
1. `CreateMultipartUpload` — initiate
2. `UploadPart` — upload chunks (5MB-5GB each)
3. `CompleteMultipartUpload` — finalize

**Presigned URLs:**
- Generate temporary access URLs (1 hour default, max 7 days)
- Use for secure, time-limited sharing without exposing credentials
- Both upload (PUT) and download (GET) presigned URLs available

**Lifecycle Policies:**
```json
{
  "Rules": [
    {"ID": "cleanup-temp", "Filter": {"Prefix": "intermediate/temp/"}, "Status": "Enabled",
     "Expiration": {"Days": 1}},
    {"ID": "archive-old", "Filter": {"Prefix": "output/"}, "Status": "Enabled",
     "Transition": [{"Days": 90, "StorageClass": "GLACIER"}]}
  ]
}
```

**CDN Integration:**
- CloudFront (AWS) or Cloudflare CDN for fast global delivery
- Cache invalidation on asset updates
- Custom domain support for branded URLs

### Google Drive

**Upload:**
```
POST https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart
Headers:
  Authorization: Bearer {access_token}
  Content-Type: multipart/related
```

**Folder Organization:**
- Create folder: POST `/drive/v3/files` with `mimeType: "application/vnd.google-apps.folder"`
- Move file to folder: PATCH `/drive/v3/files/{fileId}` with `addParents` parameter
- Mirror the project folder structure in Drive

**Sharing Permissions:**
- POST `/drive/v3/files/{fileId}/permissions`
- Roles: `reader`, `writer`, `commenter`, `owner`
- Types: `user`, `group`, `domain`, `anyone`

---

## Version Control for Creative Assets

### Version Naming Convention
- **Major versions**: v1, v2, v3 — significant changes (new concept, layout, style)
- **Minor versions**: v1.1, v1.2 — tweaks (color adjustment, text fix, crop change)
- **A/B variants**: v1a, v1b — parallel versions for testing (same concept, different execution)

### Version Management Rules
- Never overwrite a previous version — always create new file with incremented version
- Tag current/active version in manifest as `"current": true`
- Keep at least the last 3 major versions
- Intermediate/temp files do not need versioning

### Change Log Per Asset
```json
{
  "assetId": "uuid",
  "versions": [
    {"version": "v1", "date": "2026-03-06", "changes": "Initial generation", "author": "pipeline"},
    {"version": "v1.1", "date": "2026-03-06", "changes": "Color correction, brightness +10%", "author": "review"},
    {"version": "v2", "date": "2026-03-07", "changes": "New angle, different background", "author": "pipeline"}
  ]
}
```

### Rollback Strategy
- All versions stored in `generated/` or `output/` with version suffix
- Rollback: update manifest to point `"current": true` at previous version
- Re-publish: push previous version to platform with update API
- Emergency rollback: delete published post, republish previous version

---

## Deduplication

### Hash-Based Duplicate Detection
- Generate MD5 or SHA256 hash on file creation
- Store hash in asset manifest
- Before adding new asset, check hash against existing entries
- Flag exact duplicates and prompt for resolution (keep/replace/skip)

### Perceptual Hashing for Near-Duplicate Images
- Use pHash (perceptual hash) for visually similar image detection
- Hamming distance threshold: <10 = likely duplicate, <5 = near-identical
- Useful for catching re-exported or slightly cropped versions
- Libraries: Python `imagehash`, Node.js `sharp` + custom pHash

### Cleanup Scripts
```
Automated cleanup targets:
- intermediate/temp/ — delete after pipeline completion (or after 24 hours)
- generated/ files with status "rejected" — archive or delete after 7 days
- Duplicate files identified by hash — keep newest, archive others
- Files not referenced in manifest — flag as orphans for review
```

### Storage Optimization
- Compress images: WebP for web delivery, keep PNG/TIFF masters
- Video: H.265/HEVC for archive, H.264 for delivery
- Audio: AAC for delivery, WAV/FLAC for masters
- Set up automated compression pipeline for output files
- Monitor total storage usage, alert at thresholds (80%, 90%, 95%)
