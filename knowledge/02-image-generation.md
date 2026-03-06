# Image Generation & Manipulation

Comprehensive knowledge for all image creation, editing, and processing workflows. Each section is self-contained for clean chunking by OpenClaw's memory indexer.

---

## Text-to-Image: DALL-E 3

### API Endpoint and Payload
```bash
curl -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-3",
    "prompt": "YOUR_PROMPT",
    "n": 1,
    "size": "1024x1024",
    "quality": "hd",
    "style": "natural",
    "response_format": "url"
  }'
```

### Resolution Options
| Size | Aspect Ratio | Use Case |
|------|-------------|----------|
| 1024x1024 | 1:1 | Social media posts, product shots |
| 1792x1024 | 16:9 | YouTube thumbnails, banners |
| 1024x1792 | 9:16 | Stories, Reels, TikTok |

### Quality Options
- `standard` -- faster, cheaper, good for drafts ($0.040/image at 1024x1024)
- `hd` -- more detail, better coherence ($0.080/image at 1024x1024)

### Style Options
- `natural` -- photorealistic, less stylized (preferred for product shots)
- `vivid` -- more dramatic, saturated (good for marketing materials)

### Prompt Engineering for DALL-E 3
DALL-E 3 internally rewrites prompts for better results. Key strategies:
- **Be specific and descriptive**: "A professional studio photo of a matte black wireless earbud case on a white marble surface, soft diffused lighting from the left, shallow depth of field, 85mm lens"
- **Avoid**: overly short prompts, lists of unrelated items, text-heavy requests (text rendering is inconsistent)
- **Style keywords that work well**: "professional photography", "studio lighting", "editorial", "cinematic", "minimalist", "product photography", "lifestyle shot"
- **Negative guidance**: Include what you want instead of what you don't want. Say "clean white background" not "no background clutter"
- DALL-E 3 does NOT support negative prompts as a parameter

### Seed Management
DALL-E 3 does not expose a seed parameter. For reproducibility, save the revised prompt from the API response and reuse it.

### Cost Per Generation
| Size | Standard | HD |
|------|----------|----|
| 1024x1024 | $0.040 | $0.080 |
| 1024x1792 | $0.080 | $0.120 |
| 1792x1024 | $0.080 | $0.120 |

### Quality Assessment
Regenerate when:
- Text in image is garbled (common failure mode)
- Extra fingers/limbs on people
- Prompt was significantly rewritten away from intent (check `revised_prompt` in response)
- Colors don't match brand requirements

---

## Text-to-Image: gpt-image-1

### API Endpoint and Payload
```bash
curl -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-1",
    "prompt": "YOUR_PROMPT",
    "n": 1,
    "size": "1024x1024",
    "quality": "high"
  }'
```

### Key Differences from DALL-E 3
- Superior text rendering -- can accurately render words in images
- Better instruction following for complex compositions
- Supports inpainting/editing natively
- Higher cost per generation
- Quality options: `low`, `medium`, `high` (not `standard`/`hd`)

### Resolution Options
| Size | Aspect Ratio |
|------|-------------|
| 1024x1024 | 1:1 |
| 1536x1024 | 3:2 |
| 1024x1536 | 2:3 |
| Auto | Model chooses best fit |

### Prompt Engineering for gpt-image-1
- Excels at following detailed, structured prompts
- Can handle text overlay instructions: "Image with the text 'SALE 50% OFF' in bold white Impact font"
- Better at multi-element compositions than DALL-E 3
- Follows spatial instructions well: "Product in the left third, lifestyle scene in the right two-thirds"

### Cost Per Generation
Pricing is token-based (input text tokens + output image tokens). Approximate:
- Low quality 1024x1024: ~$0.011
- Medium quality 1024x1024: ~$0.042
- High quality 1024x1024: ~$0.167

---

## Text-to-Image: Midjourney

### Interaction Method
No direct REST API. Use via Discord bot commands or third-party proxies.

### Prompt Structure
```
/imagine prompt: [subject description], [style], [lighting], [camera], [mood] --ar 16:9 --v 6.1 --q 2 --s 100
```

### Parameter Reference
| Parameter | Values | Purpose |
|-----------|--------|---------|
| `--ar` | `1:1`, `16:9`, `9:16`, `4:3`, `3:2` | Aspect ratio |
| `--v` | `5.2`, `6.0`, `6.1` | Model version |
| `--q` | `0.25`, `0.5`, `1`, `2` | Quality/detail level |
| `--s` | `0`-`1000` (default 100) | Stylization amount |
| `--c` | `0`-`100` (default 0) | Chaos/variety |
| `--no` | text | Negative prompt (things to exclude) |
| `--seed` | integer | Reproducibility |
| `--style raw` | flag | Less Midjourney aesthetic, more literal |
| `--tile` | flag | Seamless tiling pattern |
| `--iw` | `0`-`2` | Image prompt weight |

### Prompt Engineering for Midjourney
**What works exceptionally well:**
- Photography terms: "shot on Canon EOS R5, 85mm f/1.4, golden hour"
- Art style references: "in the style of Wes Anderson", "Studio Ghibli aesthetic"
- Material descriptions: "brushed aluminum", "frosted glass", "velvet texture"
- Lighting: "Rembrandt lighting", "neon rim light", "soft box studio lighting"
- Mood: "ethereal", "moody", "vibrant", "muted tones"

**What to avoid:**
- Overly long prompts (diminishing returns past ~60 words)
- Conflicting instructions ("dark and bright")
- Asking for specific text (poor text rendering)

**Negative prompt examples (`--no`):**
- `--no text, watermark, signature` -- clean images
- `--no people, hands` -- avoid figure issues
- `--no blur, noise` -- sharper output

### Seed Management
Use `--seed 12345` for reproducibility. Same seed + same prompt + same parameters = similar result. The seed is shown in the job info after generation.

### Cost Per Generation
- Basic: ~$0.04/image (fast mode)
- Standard: ~$0.016/image (relaxed mode)
- Pro: ~$0.012/image
- `--q 2` doubles the cost vs `--q 1`

---

## Text-to-Image: Stable Diffusion 3 / Ultra

### API Endpoint (SD3)
```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/generate/sd3" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  -F "prompt=Professional product photography of headphones on dark surface" \
  -F "negative_prompt=blurry, low quality, distorted, watermark" \
  -F "aspect_ratio=16:9" \
  -F "model=sd3.5-large" \
  -F "seed=42" \
  -F "output_format=png" \
  --output result.png
```

### API Endpoint (Ultra)
```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/generate/ultra" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  -F "prompt=Luxury watch product shot, studio lighting" \
  -F "negative_prompt=cheap, plastic, toy" \
  -F "aspect_ratio=1:1" \
  -F "seed=42" \
  -F "output_format=png" \
  --output result.png
```

### Model Options
| Model | Endpoint | Strengths |
|-------|----------|-----------|
| SD3.5 Large | `/generate/sd3` | Best quality, slower |
| SD3.5 Large Turbo | `/generate/sd3` | Fast, good quality |
| SD3.5 Medium | `/generate/sd3` | Balanced speed/quality |
| Ultra | `/generate/ultra` | Highest quality, photorealism |
| Core | `/generate/core` | Fastest, cheapest |

### Aspect Ratio Options
`16:9`, `1:1`, `21:9`, `2:3`, `3:2`, `4:5`, `5:4`, `9:16`, `9:21`

### Negative Prompt Strategies
Stable Diffusion models benefit greatly from negative prompts. Effective negative prompts:

**Universal quality negatives:**
```
blurry, low quality, distorted, deformed, ugly, noisy, grainy, pixelated, artifacts, jpeg artifacts, watermark, text, signature, logo
```

**For product photography:**
```
blurry, low quality, distorted, cheap looking, plastic, toy-like, unrealistic shadows, harsh lighting, cluttered background, watermark
```

**For portraits:**
```
deformed, ugly, mutated, disfigured, extra limbs, extra fingers, poorly drawn hands, poorly drawn face, mutation, bad anatomy, bad proportions, cross-eyed
```

**For landscapes:**
```
blurry, low quality, oversaturated, underexposed, overexposed, HDR artifacts, chromatic aberration, lens flare, watermark
```

### Seed Management
Pass `seed` parameter (integer) for reproducibility. Same seed + same prompt + same model = identical result. Use seed `-1` or omit for random.

### Cost Per Generation
| Model | Cost (credits) | Approx USD |
|-------|---------------|------------|
| SD3.5 Large | 6.5 credits | ~$0.065 |
| SD3.5 Large Turbo | 4 credits | ~$0.040 |
| Ultra | 8 credits | ~$0.080 |
| Core | 3 credits | ~$0.030 |

---

## Text-to-Image: Flux

### API Access
Flux models available through multiple providers:
- **Replicate**: `https://api.replicate.com/v1/predictions`
- **Together AI**: `https://api.together.xyz/v1/images/generations`
- **fal.ai**: `https://fal.run/fal-ai/flux/dev`
- **BFL (Black Forest Labs)**: `https://api.bfl.ml/v1`

### Example: Flux via BFL
```bash
curl -X POST "https://api.bfl.ml/v1/flux-pro-1.1" \
  -H "x-key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Professional product photography of a smartwatch",
    "width": 1024,
    "height": 1024,
    "seed": 42
  }'
```

### Example: Flux via Replicate
```bash
curl -X POST "https://api.replicate.com/v1/predictions" \
  -H "Authorization: Bearer r8_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "flux-1.1-pro",
    "input": {
      "prompt": "Minimalist product shot of wireless earbuds",
      "aspect_ratio": "1:1",
      "output_format": "png",
      "output_quality": 90,
      "num_inference_steps": 28,
      "guidance_scale": 3.5
    }
  }'
```

### Model Variants
| Model | Strengths | Best For |
|-------|-----------|----------|
| Flux Pro 1.1 | Highest quality, best prompt adherence | Hero images, key visuals |
| Flux Dev | Good balance, open weights | Development, testing |
| Flux Schnell | Very fast (4 steps) | Drafts, previews, batch |
| Flux Pro (Fill) | Inpainting variant | Editing, object replacement |

### Prompt Engineering for Flux
- Flux excels at photorealism and prompt adherence
- Handles long, detailed prompts well (no significant degradation)
- Good at text rendering (better than SD3, comparable to gpt-image-1)
- Natural language prompts work better than keyword lists
- `guidance_scale` 3-4 is sweet spot for photorealism; higher for more literal adherence

### Seed Management
Fully deterministic with seed parameter. Same seed + same settings = identical output.

### Cost Per Generation
- Flux Pro 1.1 (BFL): ~$0.04/image
- Flux Dev (Replicate): ~$0.025/image
- Flux Schnell (Replicate): ~$0.003/image

---

## Image-to-Image: Inpainting Workflows

### What Is Inpainting
Inpainting replaces a masked region of an image with AI-generated content guided by a text prompt. Use cases: remove objects, change backgrounds, fix defects, swap products.

### Stability AI Inpainting
```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/edit/inpaint" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  -F "image=@original.png" \
  -F "mask=@mask.png" \
  -F "prompt=Clean wooden desk surface" \
  -F "negative_prompt=blurry, artifacts" \
  -F "output_format=png" \
  --output inpainted.png
```

**Mask format**: White pixels = areas to replace, black pixels = areas to keep. Same dimensions as source image.

### OpenAI Image Edit (gpt-image-1)
```bash
curl -X POST "https://api.openai.com/v1/images/edits" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -F "model=gpt-image-1" \
  -F "image=@original.png" \
  -F "mask=@mask.png" \
  -F "prompt=A red coffee mug on the desk" \
  -F "size=1024x1024"
```

**Mask format for OpenAI**: Transparent (alpha=0) pixels = areas to replace. Image must be PNG with alpha channel.

### Mask Generation Strategies
1. **Programmatic**: Use edge detection, color thresholding, or segmentation models
2. **SAM (Segment Anything)**: Point or box prompt to auto-segment objects
3. **Manual**: Create in image editor, export as PNG
4. **AI-assisted**: Use remove.bg or similar to isolate subject, invert for background mask

### Best Practices
- Feather mask edges by 5-10px for smoother blending
- Ensure mask covers slightly more than the target area
- Use prompts that describe the replacement content AND surrounding context
- Lower guidance for subtle edits, higher for dramatic changes
- Test with small masks first before full-scene edits

---

## Image-to-Image: Outpainting / Canvas Extension

### Stability AI Outpaint
```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/edit/outpaint" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  -F "image=@product.png" \
  -F "prompt=Product on an elegant marble countertop in a modern kitchen" \
  -F "left=200" \
  -F "right=200" \
  -F "up=0" \
  -F "down=100" \
  -F "output_format=png" \
  --output extended.png
```

Parameters `left`, `right`, `up`, `down` specify pixels to extend in each direction.

### Strategy for Canvas Extension
1. Start with a well-composed center image
2. Extend in small increments (100-300px) for best coherence
3. Provide prompt that describes the expected extended area
4. Multiple small extensions > one large extension for quality

---

## Image-to-Image: Style Transfer

### Using Image Prompts (Midjourney)
```
/imagine prompt: https://example.com/reference-style.jpg https://example.com/product.jpg product photography in the same style --iw 1.5
```
`--iw` controls how much the reference image influences the output (0-2, default 1).

### Using IP-Adapter (Stable Diffusion)
Via Replicate or self-hosted:
```bash
curl -X POST "https://api.replicate.com/v1/predictions" \
  -H "Authorization: Bearer r8_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "ip-adapter-model-version",
    "input": {
      "prompt": "Professional product photo",
      "image": "https://example.com/product.jpg",
      "ip_adapter_image": "https://example.com/style-reference.jpg",
      "ip_adapter_scale": 0.6
    }
  }'
```

### Best Practices
- Keep style reference and content images at similar resolutions
- Use `ip_adapter_scale` 0.4-0.7 for subtle style transfer, 0.8-1.0 for strong style adoption
- Combine with text prompt to guide the output direction

---

## Image-to-Image: Upscaling Pipelines

### Stability AI Creative Upscale
```bash
# Step 1: Initiate upscale
curl -X POST "https://api.stability.ai/v2beta/stable-image/upscale/creative" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -F "image=@low_res.png" \
  -F "prompt=High resolution product photography" \
  -F "output_format=png" \
  -F "creativity=0.3"

# Response includes generation_id
# Step 2: Poll for result
curl -X GET "https://api.stability.ai/v2beta/results/{generation_id}" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  --output upscaled.png
```

### Real-ESRGAN (via Replicate)
```bash
curl -X POST "https://api.replicate.com/v1/predictions" \
  -H "Authorization: Bearer r8_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "real-esrgan-version-hash",
    "input": {
      "image": "https://example.com/low_res.jpg",
      "scale": 4,
      "face_enhance": true
    }
  }'
```

### Upscaling Decision Matrix
| Source Quality | Target | Best Tool |
|---------------|--------|-----------|
| 256-512px, AI-generated | 2048px+ | Stability Creative Upscale |
| 512-1024px, photo | 2048-4096px | Real-ESRGAN |
| Any, with faces | Any larger | Real-ESRGAN with face_enhance |
| Product shot, needs detail | 4x+ | Stability Creative Upscale (creativity 0.2-0.4) |

---

## Image-to-Image: Background Removal

### Stability AI Remove Background
```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/edit/remove-background" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  -F "image=@product.jpg" \
  -F "output_format=png" \
  --output product_nobg.png
```

### remove.bg API
```bash
curl -X POST "https://api.remove.bg/v1.0/removebg" \
  -H "X-Api-Key: YOUR_KEY" \
  -F "image_file=@product.jpg" \
  -F "size=full" \
  -F "type=product" \
  -F "format=png" \
  --output product_nobg.png
```

### Options for remove.bg
| Parameter | Values | Purpose |
|-----------|--------|---------|
| `size` | `preview`, `full`, `auto` | Output resolution |
| `type` | `auto`, `person`, `product`, `car` | Subject type hint |
| `crop` | `true`/`false` | Crop to subject |
| `bg_color` | hex code | Replace background with color |
| `bg_image_url` | URL | Replace background with image |

### Cost Comparison
| Service | Free Tier | Paid |
|---------|-----------|------|
| Stability AI | Credits-based | ~$0.02/image |
| remove.bg | 1 free/month (preview) | $0.20/image (full quality) |
| Replicate (various models) | Per-second billing | ~$0.01-0.03/image |

---

## Image-to-Image: Face Restoration

### GFPGAN / CodeFormer (via Replicate)
```bash
curl -X POST "https://api.replicate.com/v1/predictions" \
  -H "Authorization: Bearer r8_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "codeformer-version-hash",
    "input": {
      "image": "https://example.com/face.jpg",
      "codeformer_fidelity": 0.7,
      "background_enhance": true,
      "face_upsample": true,
      "upscale": 2
    }
  }'
```

### When to Use
- AI-generated faces with subtle artifacts
- Low-resolution source images of people
- Video frames with compression artifacts on faces
- `codeformer_fidelity`: 0.5 = more enhancement, 1.0 = more faithful to original

---

## Image Editing Automation: Color Correction & Grading

### Programmatic Color Correction (FFmpeg)
```bash
# Auto-levels (normalize histogram)
ffmpeg -i input.png -vf "normalize=blackpt=black:whitept=white:smoothing=0" output.png

# Adjust brightness, contrast, saturation
ffmpeg -i input.png -vf "eq=brightness=0.06:contrast=1.2:saturation=1.3" output.png

# Color temperature (warm shift)
ffmpeg -i input.png -vf "colorbalance=rs=0.1:gs=0:bs=-0.1:rm=0.1:gm=0:bm=-0.1" output.png

# Apply LUT for cinematic grading
ffmpeg -i input.png -vf "lut3d=cinematic.cube" output.png
```

### Python (Pillow) Color Adjustment
```python
from PIL import Image, ImageEnhance

img = Image.open("product.jpg")
img = ImageEnhance.Brightness(img).enhance(1.1)     # +10% brightness
img = ImageEnhance.Contrast(img).enhance(1.2)        # +20% contrast
img = ImageEnhance.Color(img).enhance(1.15)           # +15% saturation
img = ImageEnhance.Sharpness(img).enhance(1.3)        # +30% sharpness
img.save("product_corrected.jpg", quality=95)
```

### Brand-Consistent Color Grading
Apply the same adjustments across all images in a campaign:
1. Define a grading profile (brightness, contrast, saturation, color balance values)
2. Store as JSON config alongside brand assets
3. Apply programmatically in batch before publish

---

## Image Editing Automation: Text Overlay & Typography

### Rules for Text on Images
1. **Contrast**: minimum 4.5:1 ratio (WCAG AA). Use white text on dark images, dark text on light images
2. **Safe zones**: keep text within 80% of image center area, away from edges
3. **Font size**: minimum 24px for social media, 48px+ for thumbnails
4. **Font weight**: bold or semibold for headlines; regular for body text
5. **Background**: semi-transparent overlay behind text improves readability
6. **Limit**: maximum 2 font families per image

### FFmpeg Text Overlay
```bash
ffmpeg -i background.png -vf \
  "drawtext=text='SALE 50%% OFF':fontfile=/path/to/font.ttf:fontsize=72:fontcolor=white:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2" \
  output.png
```

### Python (Pillow) Text Overlay
```python
from PIL import Image, ImageDraw, ImageFont

img = Image.open("background.jpg")
draw = ImageDraw.Draw(img)
font = ImageFont.truetype("Montserrat-Bold.ttf", 72)

# Center text
text = "NEW ARRIVAL"
bbox = draw.textbbox((0, 0), text, font=font)
text_w, text_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
x = (img.width - text_w) // 2
y = (img.height - text_h) // 2

# Semi-transparent background
overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
overlay_draw = ImageDraw.Draw(overlay)
padding = 20
overlay_draw.rectangle(
    [x - padding, y - padding, x + text_w + padding, y + text_h + padding],
    fill=(0, 0, 0, 128)
)
img = Image.alpha_composite(img.convert('RGBA'), overlay)

draw = ImageDraw.Draw(img)
draw.text((x, y), text, fill="white", font=font)
img.save("output.png")
```

---

## Image Editing Automation: Brand Consistency

### Brand Asset Configuration
```json
{
  "brand": {
    "colors": {
      "primary": "#1A73E8",
      "secondary": "#34A853",
      "accent": "#FBBC04",
      "text_dark": "#202124",
      "text_light": "#FFFFFF",
      "background": "#F8F9FA"
    },
    "fonts": {
      "headline": "Montserrat-Bold",
      "body": "Open Sans",
      "accent": "Playfair Display"
    },
    "logo": {
      "primary": "assets/logo-dark.svg",
      "inverted": "assets/logo-light.svg",
      "icon_only": "assets/logo-icon.svg",
      "min_clear_space": "20px"
    },
    "image_style": {
      "filter": "slight warm shift, +10% contrast",
      "corner_radius": "12px",
      "shadow": "0 4px 12px rgba(0,0,0,0.15)"
    }
  }
}
```

### Consistency Checklist
1. All images use brand color palette for overlays and accents
2. Logo placement consistent (e.g., bottom-right, with clear space)
3. Same font family across all creatives
4. Color grading profile applied uniformly
5. Aspect ratios match platform requirements
6. Watermark/logo opacity consistent (recommended: 60-80%)

---

## Image Editing Automation: Thumbnail Templates

### YouTube Thumbnail (1280x720)
```
Layout:
- Left 60%: Hero image or face (large, eye-catching)
- Right 40%: Bold text (2-4 words max)
- Bottom bar: Subtle brand color strip (10px)
- Font: 80-120px bold, with 4px stroke for contrast

Key rules:
- Faces with emotion get 2-3x more clicks
- Use max 3 colors
- High contrast between text and background
- Avoid small text (invisible at thumbnail size)
```

### Instagram Post (1080x1080)
```
Layout options:
1. Full-bleed product shot with text overlay
2. Split: 50% product image, 50% solid color background with text
3. Carousel: consistent border/frame across slides

Key rules:
- Keep key content in center 90% (square crop safe zone)
- Font minimum 32px
- Brand handle or logo subtly placed
```

### TikTok / Reels Cover (1080x1920)
```
Layout:
- Top 30%: Hook text (large, bold)
- Center 40%: Key visual / product
- Bottom 30%: CTA or additional text
- Safe zone: keep text within center 80% horizontally, avoid top/bottom 15%

Key rules:
- Vertical orientation mandatory
- Bright, high-contrast colors
- Text must be readable at small sizes (mobile feed)
```

---

## Image Editing Automation: Product Photography Enhancement

### Standard Enhancement Pipeline
1. **Background removal** (Stability AI or remove.bg)
2. **Place on clean background** (white, gradient, or lifestyle scene via inpainting)
3. **Shadow generation** (programmatic drop shadow or AI-generated contact shadow)
4. **Color correction** (match brand palette, ensure product colors are accurate)
5. **Sharpening** (unsharp mask, light touch)
6. **Resize and export** for each platform target size

### Shadow Generation (Pillow)
```python
from PIL import Image, ImageFilter

product = Image.open("product_nobg.png")  # RGBA with transparency

# Create shadow
shadow = Image.new('RGBA', product.size, (0, 0, 0, 0))
shadow.paste(Image.new('RGBA', product.size, (0, 0, 0, 80)), mask=product.split()[3])
shadow = shadow.filter(ImageFilter.GaussianBlur(radius=15))

# Offset shadow
canvas = Image.new('RGBA', (product.width + 40, product.height + 40), (255, 255, 255, 255))
canvas.paste(shadow, (20, 25), shadow)  # shadow offset down-right
canvas.paste(product, (10, 10), product)
canvas.save("product_with_shadow.png")
```

---

## Image Editing Automation: Batch Processing

### Pattern: Process Multiple Images
```python
import os
from pathlib import Path

INPUT_DIR = Path("raw_images")
OUTPUT_DIR = Path("processed_images")
OUTPUT_DIR.mkdir(exist_ok=True)

async def batch_process(pipeline_steps: list):
    images = list(INPUT_DIR.glob("*.{jpg,png,webp}"))
    results = []

    for i, image_path in enumerate(images):
        print(f"Processing {i+1}/{len(images)}: {image_path.name}")
        result = image_path
        for step in pipeline_steps:
            result = await step(result)
        results.append(result)

    return results

# Usage
pipeline = [
    remove_background,      # API call to Stability/remove.bg
    color_correct,           # Local Pillow processing
    add_brand_overlay,       # Local Pillow processing
    resize_for_platforms,    # Generates multiple sizes
    upload_to_storage,       # Upload to Dropbox/Drive
]

await batch_process(pipeline)
```

### Parallel Batch with Rate Limiting
```python
import asyncio
from asyncio import Semaphore

async def batch_with_rate_limit(images, process_fn, max_concurrent=5):
    semaphore = Semaphore(max_concurrent)

    async def limited_process(image):
        async with semaphore:
            return await process_fn(image)

    return await asyncio.gather(*[limited_process(img) for img in images])
```

---

## Prompt Engineering Deep Dive

### Anatomy of a Perfect Prompt

A well-structured prompt contains these elements in order of importance:

```
[Subject] + [Action/Pose] + [Style/Medium] + [Lighting] + [Camera/Lens] + [Mood/Atmosphere] + [Details/Extras]
```

**Example breakdown:**
```
A professional product photograph           [Style/Medium]
of a sleek matte black wireless earbud case [Subject + Details]
resting on a white marble surface           [Setting]
with soft diffused lighting from the left   [Lighting]
shot with an 85mm f/1.4 lens               [Camera]
shallow depth of field                      [Camera detail]
minimalist composition                      [Mood]
clean, modern aesthetic                     [Atmosphere]
editorial quality                           [Quality modifier]
```

### Platform-Specific Prompt Differences

| Element | DALL-E 3 | gpt-image-1 | Midjourney | Stable Diffusion | Flux |
|---------|----------|-------------|------------|-----------------|------|
| Prompt style | Natural language | Natural language | Keyword-heavy | Keywords + weights | Natural language |
| Optimal length | 1-3 sentences | 1-4 sentences | 30-60 words | 20-50 words | 1-4 sentences |
| Negative prompts | Not supported | Not supported | `--no` flag | `negative_prompt` param | Not standard |
| Style refs | Describe in text | Describe in text | `--sref` URL | IP-Adapter | Image prompt |
| Text rendering | Poor | Good | Poor | Poor | Good |
| Weights | Not supported | Not supported | `::weight` syntax | `(word:1.3)` syntax | Not standard |

### Negative Prompt Libraries

**Universal base negative (for SD3/Flux where supported):**
```
blurry, low quality, low resolution, pixelated, noisy, grainy, artifacts, jpeg artifacts, compression artifacts, watermark, text, signature, logo, username, artist name, cropped, out of frame, worst quality, normal quality
```

**Product photography negatives:**
```
blurry, low quality, distorted perspective, uneven lighting, harsh shadows, color cast, fingerprints, dust, scratches, reflections of photographer, cluttered background, busy background, distracting elements, text overlay, watermark
```

**Portrait negatives:**
```
deformed, ugly, mutated, disfigured, extra limbs, extra fingers, fused fingers, too many fingers, poorly drawn hands, poorly drawn face, bad anatomy, bad proportions, gross proportions, malformed limbs, missing arms, missing legs, extra arms, extra legs, long neck, cross-eyed, distorted face
```

**Landscape/architecture negatives:**
```
blurry, low quality, distorted, warped, tilted horizon, oversaturated, underexposed, overexposed, HDR artifacts, chromatic aberration, lens flare, vignette, watermark, people, cars, modern elements (for historical), anachronistic elements
```

---

## Few-Shot Prompt Templates

### Product Shots
```
Template: "A professional {product_type} product photograph of {product_description} on {surface_material}, {lighting_setup}, {camera_spec}, {composition_style}, {mood}"

Examples:
- "A professional product photograph of a rose gold smartwatch on brushed concrete surface, soft diffused studio lighting from two directions, shot with 100mm macro lens f/2.8, centered composition with negative space, clean and premium aesthetic"
- "A professional product photograph of organic skincare bottles on white linen fabric, natural window light from the right, shot with 50mm lens, flat lay arrangement, fresh and minimal"
```

### Lifestyle Shots
```
Template: "A {mood} lifestyle photograph showing {person_description} {action} with {product}, in {setting}, {lighting}, {style_keywords}"

Examples:
- "A warm lifestyle photograph showing a young professional woman using wireless earbuds while jogging in an urban park at golden hour, natural sunlight, candid and authentic, editorial quality"
- "A cozy lifestyle photograph showing hands holding a ceramic coffee mug in a minimalist kitchen, soft morning light through windows, shallow depth of field, hygge aesthetic"
```

### Portraits
```
Template: "{portrait_type} portrait of {subject_description}, {expression}, {lighting_setup}, {background}, {camera_spec}, {mood}"

Examples:
- "Professional headshot portrait of a confident businesswoman in her 30s, warm genuine smile, Rembrandt lighting with soft fill, clean dark gray background, 85mm f/1.8, corporate and approachable"
- "Environmental portrait of a craftsman in his workshop, focused expression, dramatic side lighting, bokeh tools background, 35mm wide angle, authentic and gritty"
```

### Landscapes
```
Template: "{time_of_day} landscape photograph of {location_description}, {weather_conditions}, {compositional_element}, {camera_spec}, {style}"

Examples:
- "Golden hour landscape photograph of rolling Tuscan hills with cypress trees, clear sky with warm haze, leading lines from a stone path, 24mm wide angle, Fujifilm Velvia color rendition"
- "Moody overcast seascape of rocky Nordic coastline, dramatic storm clouds, long exposure smooth water, 16mm ultra-wide, fine art black and white"
```

### Abstract / Background
```
Template: "{style} abstract {subject}, {color_palette}, {texture}, {mood}, suitable for {use_case}"

Examples:
- "Fluid abstract gradient, deep navy blue to teal to white, smooth silk texture, calm and premium, suitable for website hero background"
- "Geometric abstract pattern, coral and gold on dark charcoal, sharp angular shapes, modern and bold, suitable for social media template background"
```

### Infographics
```
Template: "{style} infographic {layout_type} about {topic}, {color_scheme}, {icon_style}, clean and readable, {dimensions}"

Note: For infographics, AI image generation typically creates the visual style/template. Actual data and text should be overlaid programmatically for accuracy.

Examples:
- "Clean modern infographic template with 4 sections, blue and white color scheme, flat design icons, data visualization placeholders, 1080x1920 vertical format"
```

---

## Dynamic Prompt Construction

### Variable-Based Prompt Builder
```python
def build_product_prompt(product: dict, style: dict) -> str:
    """Build a prompt from structured product and style data."""
    components = [
        f"A professional {style.get('genre', 'product')} photograph",
        f"of {product['name']}",
    ]

    if product.get('color'):
        components.append(f"in {product['color']}")

    if product.get('material'):
        components.append(f"made of {product['material']}")

    surface = style.get('surface', 'clean white background')
    components.append(f"on {surface}")

    lighting = style.get('lighting', 'soft studio lighting')
    components.append(lighting)

    camera = style.get('camera', 'shot with 85mm lens')
    components.append(camera)

    mood = style.get('mood', 'premium and minimal')
    components.append(mood)

    quality = "editorial quality, high resolution, sharp focus"
    components.append(quality)

    return ", ".join(components)

# Usage
prompt = build_product_prompt(
    product={"name": "wireless earbuds", "color": "matte black", "material": "aluminum"},
    style={"surface": "dark slate", "lighting": "dramatic side lighting", "mood": "tech and modern"}
)
# Output: "A professional product photograph, of wireless earbuds, in matte black, made of aluminum, on dark slate, dramatic side lighting, shot with 85mm lens, tech and modern, editorial quality, high resolution, sharp focus"
```

### Platform-Adaptive Prompt
```python
def adapt_prompt_for_platform(base_prompt: str, platform: str, params: dict = None) -> dict:
    """Adapt a base prompt for different generation platforms."""

    if platform == "dalle3":
        return {
            "model": "dall-e-3",
            "prompt": base_prompt,
            "quality": params.get("quality", "hd"),
            "style": params.get("style", "natural"),
            "size": params.get("size", "1024x1024")
        }
    elif platform == "sd3":
        negative = params.get("negative", "blurry, low quality, distorted, watermark")
        return {
            "prompt": base_prompt,
            "negative_prompt": negative,
            "aspect_ratio": params.get("aspect_ratio", "1:1"),
            "model": params.get("model", "sd3.5-large"),
            "seed": params.get("seed", -1)
        }
    elif platform == "midjourney":
        mj_params = []
        if params.get("ar"):
            mj_params.append(f"--ar {params['ar']}")
        mj_params.append(f"--v {params.get('version', '6.1')}")
        mj_params.append(f"--q {params.get('quality', '2')}")
        if params.get("no"):
            mj_params.append(f"--no {params['no']}")
        if params.get("seed"):
            mj_params.append(f"--seed {params['seed']}")
        param_str = " ".join(mj_params)
        return {"prompt": f"{base_prompt} {param_str}"}
    elif platform == "flux":
        return {
            "prompt": base_prompt,
            "width": params.get("width", 1024),
            "height": params.get("height", 1024),
            "num_inference_steps": params.get("steps", 28),
            "guidance_scale": params.get("guidance", 3.5),
            "seed": params.get("seed", -1)
        }
    elif platform == "gpt-image-1":
        return {
            "model": "gpt-image-1",
            "prompt": base_prompt,
            "quality": params.get("quality", "high"),
            "size": params.get("size", "1024x1024")
        }
```

### Quality Assessment Automation
```python
def should_regenerate(image_path: str, criteria: dict) -> tuple[bool, list[str]]:
    """
    Check if an image meets quality criteria.
    Returns (should_regenerate, list_of_issues).
    """
    issues = []

    img = Image.open(image_path)

    # Check resolution
    min_res = criteria.get("min_resolution", (1024, 1024))
    if img.width < min_res[0] or img.height < min_res[1]:
        issues.append(f"Resolution {img.size} below minimum {min_res}")

    # Check aspect ratio
    expected_ar = criteria.get("aspect_ratio")
    if expected_ar:
        actual_ar = img.width / img.height
        tolerance = 0.05
        if abs(actual_ar - expected_ar) > tolerance:
            issues.append(f"Aspect ratio {actual_ar:.2f} doesn't match expected {expected_ar}")

    # Check if mostly blank/white (failed generation)
    pixels = list(img.getdata())
    white_count = sum(1 for p in pixels if all(c > 250 for c in p[:3]))
    if white_count / len(pixels) > 0.9:
        issues.append("Image appears to be mostly blank/white")

    # Check sharpness (Laplacian variance)
    import cv2
    import numpy as np
    cv_img = cv2.imread(image_path)
    gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    if laplacian_var < criteria.get("min_sharpness", 100):
        issues.append(f"Image may be blurry (sharpness: {laplacian_var:.1f})")

    return (len(issues) > 0, issues)
```

---

## Search and Replace (Object Swap)

### Stability AI Search & Replace
```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/edit/search-and-replace" \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Accept: image/*" \
  -F "image=@scene.jpg" \
  -F "prompt=A red sports car" \
  -F "search_prompt=the blue sedan" \
  -F "output_format=png" \
  --output replaced.png
```

No mask needed -- the model finds and replaces the described object automatically.

### Use Cases
- Swap product variants (color changes, model updates)
- Replace background elements
- Localize images (swap signage, text, cultural elements)
- A/B test different product placements in same scene

---

## Platform Selection Guide

### Quick Decision Matrix
| Need | Best Platform | Runner-Up |
|------|--------------|-----------|
| Photorealistic products | Flux Pro 1.1 | Midjourney v6.1 |
| Text in images | gpt-image-1 | Flux Pro 1.1 |
| Artistic/stylized | Midjourney v6.1 | DALL-E 3 (vivid) |
| Speed (drafts) | Flux Schnell | SD3.5 Turbo |
| Lowest cost | Flux Schnell ($0.003) | SD Core ($0.03) |
| Best inpainting | gpt-image-1 | Stability AI |
| Background removal | Stability AI | remove.bg |
| Upscaling | Stability Creative | Real-ESRGAN |
| Batch processing | Stability API | Flux via Replicate |
| Prompt adherence | Flux Pro 1.1 | gpt-image-1 |
| Avatars/people | Higgsfield Soul | Midjourney v6.1 |
| Free (no API cost) | ChatGPT browser | Higgsfield free tier |

---

## Text-to-Image: Higgsfield Soul

### Overview
Higgsfield Soul is specialized for generating **human avatars and presenter images**. It excels at creating photorealistic people for talking-head videos, brand ambassadors, and character-consistent content.

### API Endpoint
```bash
curl -X POST "https://platform.higgsfield.ai/api/v1/soul/generate" \
  -H "hf-api-key: YOUR_API_KEY" \
  -H "hf-secret: YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "professional woman, 30s, business attire, confident smile, studio lighting, clean background",
    "style": "photorealistic",
    "width": 1024,
    "height": 1024,
    "num_images": 1
  }'
```

### Best Use Cases
- **Talking-head presenters**: Generate consistent avatar for lip-sync videos
- **Brand ambassadors**: Create fictional but realistic brand representatives
- **Character consistency**: Same character across multiple scenes/poses
- **Social media profile images**: Professional headshots and lifestyle shots

### Prompt Tips for Soul
- Be specific about age, gender, ethnicity, expression, clothing
- Specify lighting: "studio lighting", "natural outdoor", "warm golden hour"
- Include pose: "looking at camera", "slight smile", "professional stance"
- Background: "clean white", "office setting", "blurred bokeh"
- For video pipeline: generate with "neutral expression, front-facing" for best lip-sync results

### Advantages Over Other Image Generators
- Optimized for human faces (fewer artifacts, better proportions)
- Designed to feed directly into DoP (image-to-video) and Speak (lip-sync)
- Character consistency across generations with same prompt
- Free tier available (generous limits for prototyping)

---

## Text-to-Image: ChatGPT Browser (DALL-E via Chat)

### Overview
ChatGPT's browser interface provides access to DALL-E image generation without API costs. ClawBot can use browser automation to generate images through ChatGPT's web interface.

### When to Use
- No API key configured or API quota exhausted
- Cost-sensitive projects (browser access is included in ChatGPT subscription)
- Iterative design (easy to refine through conversation)
- Complex prompts that benefit from ChatGPT's prompt enhancement

### Workflow
```
1. Login to https://chat.openai.com (browser automation)
2. Create new conversation
3. Send: "Generate an image: [detailed prompt]"
4. ChatGPT may enhance/modify your prompt — review what it generates
5. If needed: "Regenerate with these changes: [specifics]"
6. Download generated image from the chat
7. For consistency: "Create 3 more images in the same style as above"
```

### Prompt Strategy for ChatGPT
- ChatGPT tends to "improve" prompts — if you want exact control, say:
  "Generate exactly as I describe, do not modify or enhance the prompt"
- For brand consistency: describe the brand visual style in detail first
- For batch work: ask for variations in a single conversation
- Aspect ratio: specify explicitly ("in portrait 9:16 format")

### Limitations
- Slower than direct API calls (requires browser interaction)
- Rate limited by ChatGPT's usage caps (varies by subscription tier)
- Cannot specify exact API parameters (quality, style, etc.)
- Image URLs expire — download immediately
- ChatGPT Plus/Pro required for reliable access
