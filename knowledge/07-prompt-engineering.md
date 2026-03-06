# Prompt Engineering Mastery

## Meta-Prompting

### Prompts That Generate Better Prompts
- Use a "prompt generator" pattern: describe the desired output, let the AI draft the prompt, then refine iteratively
- Template: "You are a prompt engineer. Write an optimized prompt for [model] that generates [desired output]. Include style, lighting, composition, and mood details."
- Self-refining loop: generate prompt -> generate output -> evaluate -> ask AI to improve the prompt -> repeat

### Self-Refining Prompt Patterns
- Reflection pattern: append "Before answering, analyze what makes a great [output type] and incorporate those qualities"
- Critique-and-improve: "Generate [content], then critique it, then produce an improved version"
- Multi-perspective: "Approach this from the perspective of a [photographer/designer/marketer], then synthesize"

### Chain-of-Thought for Complex Creative Tasks
- Break creative briefs into sequential reasoning steps
- Example: "First, identify the core emotion. Then, choose a visual metaphor. Then, describe the scene composition. Finally, write the full prompt."
- Use numbered steps to force structured thinking
- Combine with few-shot examples for consistent quality

### Prompt Versioning and Iteration
- Track every prompt version with its output quality score
- Store in `metadata/prompts.json` with fields: version, prompt_text, model, output_score, notes
- A/B test prompt variants by generating multiple outputs and scoring
- Maintain a "prompt library" of proven templates per content type

---

## Platform-Specific Prompt Guides

### DALL-E 3 / gpt-image-1

**Structure:** `[subject] + [action/pose] + [setting/background] + [style] + [lighting] + [camera angle] + [mood/atmosphere] + [additional details]`

**Best Style Keywords:**
- Realistic: photorealistic, cinematic, hyperrealistic, documentary style
- Artistic: watercolor, oil painting, digital art, charcoal sketch, gouache
- 3D/Tech: 3D render, isometric, low poly, voxel art, CGI
- Design: flat design, minimalist, vector illustration, infographic style
- Aesthetic: retro, vintage, cyberpunk, steampunk, art nouveau, pop art, vaporwave, cottagecore

**Lighting Keywords:**
- Natural: golden hour, blue hour, overcast soft light, harsh midday sun, dappled forest light
- Studio: studio lighting, softbox, ring light, beauty dish, three-point lighting
- Dramatic: dramatic side lighting, backlit, rim lighting, Rembrandt lighting, chiaroscuro
- Atmospheric: volumetric, neon glow, candlelight, bioluminescent, moonlit
- Technical: high-key, low-key, split lighting, butterfly lighting

**Camera Keywords:**
- Distance: extreme close-up, close-up, medium shot, wide angle, panoramic
- Angle: bird's eye view, worm's eye view, Dutch angle, straight-on, over-the-shoulder
- Lens: macro, 35mm, 50mm, 85mm bokeh, 200mm telephoto compression, tilt-shift, fish-eye
- Movement: drone shot, tracking shot, dolly zoom, steadicam

**Negative Approach:**
DALL-E does not support negative prompts directly. Instead of saying "no blurry background," say "sharp, in-focus background with crisp details." Specify exactly what you want rather than what you don't want.

**Quality Boosters:**
- "highly detailed", "intricate details", "professional photography"
- "award-winning", "editorial quality", "magazine cover quality"
- "8K resolution", "ultra high definition", "razor sharp"
- "masterfully composed", "perfect composition"

---

### Midjourney

**Structure:** `[subject description] -- [parameters]`

**Core Parameters:**
- `--ar` — Aspect ratio (e.g., `--ar 16:9`, `--ar 9:16`, `--ar 1:1`)
- `--v` — Version (e.g., `--v 6.1`)
- `--s` — Stylize: 0 (literal) to 1000 (highly stylized), default 100
- `--c` — Chaos: 0 (consistent) to 100 (varied), controls variation between outputs
- `--q` — Quality: 0.25 (draft), 0.5 (half), 1 (default), 2 (high detail)
- `--no` — Negative prompts (e.g., `--no text watermark blur`)
- `--style raw` — Less Midjourney default styling, more literal interpretation
- `--niji` — Anime/illustration mode
- `--tile` — Creates seamless tileable patterns
- `--seed` — Reproducibility (e.g., `--seed 12345`)

**Multi-Prompt Weighting:**
- Use `::` to separate and weight concepts
- Example: `cat::2 astronaut suit::1 space background::1` — cat is weighted 2x
- Negative weights: `vibrant scene:: text::-0.5` — reduces text appearance

**Best Practices:**
- Front-load the most important concepts
- Reference specific artists or photographers for style (e.g., "in the style of Annie Leibovitz")
- Use `--s 250-750` for creative work, `--s 0-100` for literal interpretation
- Combine `--c 20-40` with `--s 500+` for creative exploration
- Use `/describe` on reference images to reverse-engineer effective prompts

---

### Stable Diffusion 3

**Positive Prompt Structure:**
Similar to DALL-E — subject, action, setting, style, lighting, camera. Supports more technical syntax.

**Negative Prompt Essentials:**
```
blurry, low quality, deformed, ugly, bad anatomy, extra limbs, extra fingers,
mutated hands, poorly drawn face, mutation, out of frame, cropped, worst quality,
low resolution, text, watermark, signature, jpeg artifacts, duplicate, morbid,
disfigured, bad proportions, gross proportions, missing arms, missing legs,
extra arms, extra legs, fused fingers, too many fingers, long neck
```

**CFG Scale Guidance:**
- 1-4: Very creative, loose interpretation (experimental)
- 5-7: Balanced creativity and prompt adherence
- 7-12: Strong prompt adherence (recommended for most use cases)
- 12-20: Very literal, can become oversaturated
- Sweet spot for most content: 7-9

**Sampler Selection:**
- DPM++ 2M Karras — balanced quality and speed (general purpose)
- Euler a — creative, good for artistic styles, slight variation per step count
- DDIM — deterministic, consistent outputs, good for reproducibility
- DPM++ SDE Karras — high quality, slower, good for photorealistic
- UniPC — fast convergence, fewer steps needed

**LoRA/Embedding Integration:**
- LoRA syntax: `<lora:model_name:weight>` (weight 0.0-1.0, typically 0.6-0.8)
- Textual inversion: use the trigger word defined in the embedding
- Stack multiple LoRAs but reduce individual weights to avoid conflicts

---

### Flux

**Prompt Format:**
- Natural language descriptions work best (no need for comma-separated tags)
- Supports longer, more descriptive prompts than earlier diffusion models
- Emphasize narrative descriptions over keyword lists

**Flow Matching vs Diffusion:**
- Flux uses rectified flow matching — straighter sampling paths
- Result: fewer steps needed (20-30 vs 50+ for SD), faster generation
- More consistent quality across different step counts
- Better text rendering in generated images

**Quality Parameters:**
- Steps: 20-30 typically sufficient (vs 30-50 for SD)
- Guidance: 3.5-7.0 (lower range than SD due to flow matching)
- Flux Pro vs Flux Dev vs Flux Schnell: quality/speed tradeoffs
- Schnell: 1-4 steps for rapid prototyping
- Dev: 20-30 steps for quality output
- Pro: API-only, highest quality

---

## Content-Type Prompt Templates

### 1. Product Photography
```
Prompt A: "Professional product photography of {product_name} on a clean white seamless background, studio lighting with soft shadows, 45-degree angle, sharp focus, commercial quality, 85mm lens"

Prompt B: "Minimalist product shot of {product_name} floating with a subtle shadow below, gradient background in {brand_color}, soft diffused lighting from above, catalog style, 8K detail"

Prompt C: "Flat lay product photography of {product_name} surrounded by complementary lifestyle props, marble surface, natural window light from the left, editorial style, overhead shot"
```

### 2. Lifestyle Images
```
Prompt A: "Candid lifestyle photograph of a {target_audience} person naturally using {product_name} in a modern coffee shop, warm ambient lighting, shallow depth of field, authentic and unstaged feel, 35mm documentary style"

Prompt B: "Young professional smiling while interacting with {product_name} outdoors in an urban park, golden hour sunlight, bokeh background of city skyline, aspirational and relatable mood"

Prompt C: "Cozy home setting with {product_name} integrated into daily routine, soft morning light through sheer curtains, hygge aesthetic, warm color palette, lifestyle editorial"
```

### 3. Portrait/Headshot
```
Prompt A: "Professional corporate headshot, confident smile, clean neutral background, studio lighting with catchlights in eyes, sharp focus on face, business attire, approachable and trustworthy"

Prompt B: "Creative professional portrait with colorful {brand_color} gel lighting, modern studio setting, slight three-quarter turn, engaging eye contact, contemporary and dynamic"

Prompt C: "Environmental portrait of a professional in their workspace, natural light from large windows, depth showing workspace context, authentic and warm, editorial quality"
```

### 4. Landscape/Scenery
```
Prompt A: "Sweeping cinematic landscape of mountains at golden hour, dramatic clouds, vibrant warm tones, foreground wildflowers, wide-angle 16mm lens, National Geographic quality"

Prompt B: "Moody coastal scene with waves crashing against rocky cliffs, overcast sky with god rays breaking through clouds, long exposure silky water, dramatic and contemplative"

Prompt C: "Aerial drone shot of a lush green valley with a winding river, morning mist in the valley, warm sunrise light, DJI Mavic quality, establishing shot feel"
```

### 5. Abstract/Conceptual
```
Prompt A: "Abstract visualization of {brand_value} concept, flowing liquid forms in {brand_color}, dynamic motion, dark background, glossy reflective surfaces, 3D render, cinema 4D quality"

Prompt B: "Conceptual art representing innovation and growth, geometric shapes morphing into organic forms, gradient from {brand_color} to complementary tone, modern and sophisticated"

Prompt C: "Surreal dreamscape symbolizing connection and trust, interconnected luminous threads on deep blue background, ethereal glow, minimalist composition, fine art quality"
```

### 6. Infographic/Data Visualization
```
Prompt A: "Clean modern infographic layout showing growth metrics, {brand_color} color scheme, flat design icons, clear hierarchy, white background, minimalist and professional"

Prompt B: "Data visualization dashboard with pie charts and bar graphs in {brand_color} palette, dark mode design, glowing accents, tech-forward aesthetic, readable at all sizes"

Prompt C: "Step-by-step process infographic with numbered circular icons, connecting lines, {brand_color} accents on white, modern sans-serif typography style, business presentation quality"
```

### 7. Meme/Viral Content
```
Prompt A: "Expressive reaction face with exaggerated surprise expression, clean white background, bold and simple, meme-ready composition, high contrast, easily recognizable at small sizes"

Prompt B: "Split-screen comparison image, left side chaotic and messy, right side organized and clean, comedic contrast, relatable everyday scenario, shareable format"

Prompt C: "Cute animal (golden retriever) in an unexpected human situation, wearing tiny glasses at a desk, office setting, funny and heartwarming, viral potential, perfectly lit"
```

### 8. Thumbnail
```
Prompt A: "YouTube thumbnail style image, extreme close-up of an excited face with mouth open, bright {brand_color} background, high contrast, bold and attention-grabbing, readable at 320px width"

Prompt B: "Before-and-after split thumbnail, dramatic transformation, left side dull and grey, right side vibrant and colorful, clear visual storytelling, clickable composition"

Prompt C: "Dynamic action shot with motion blur background, subject in sharp focus center frame, bold complementary colors, visual tension, thumbnail-optimized high contrast"
```

### 9. Social Media Banner
```
Prompt A: "Professional social media banner, {brand_color} gradient background, subtle geometric pattern overlay, clean left-third for logo/text placement, modern and cohesive, 1500x500px composition"

Prompt B: "Lifestyle banner image with product placement on the right third, blurred lifestyle background, warm tones, space on left for text overlay, brand-consistent aesthetic"

Prompt C: "Abstract wave pattern banner in {brand_color} palette, smooth gradient transitions, subtle texture, professional and versatile, works across all social platforms"
```

### 10. Ad Creative
```
Prompt A: "Scroll-stopping ad image featuring {product_name} with bold visual contrast, {brand_color} accent frame, clean space for CTA button placement, commercial quality, conversion-optimized layout"

Prompt B: "Problem-solution split image for ad creative, left side showing frustration (muted tones), right side showing relief with {product_name} (vibrant), clear visual narrative"

Prompt C: "Aspirational lifestyle ad creative, beautiful person enjoying life with {product_name} subtly visible, golden hour warmth, premium feel, luxury brand aesthetic, magazine ad quality"
```

---

## Dynamic Prompt Construction

### Template Variables
Core variables to inject into prompt templates:
- `{product_name}` — Product or service name
- `{brand_color}` — Primary brand color (e.g., "emerald green", "#2ECC71")
- `{target_audience}` — Audience descriptor (e.g., "millennial professionals", "Gen-Z students")
- `{mood}` — Emotional tone (e.g., "energetic", "calm", "luxurious", "playful")
- `{platform}` — Target platform for format/style adaptation
- `{season}` — Seasonal context (e.g., "summer", "holiday season")
- `{cta}` — Call to action context affecting visual emphasis

### Conditional Prompt Segments Based on Platform
```
IF platform == "instagram_reels":
    append "vertical composition 9:16, mobile-first framing, bold colors visible on small screen"
ELIF platform == "youtube_thumbnail":
    append "horizontal 16:9, high contrast, face focused, readable at 320px"
ELIF platform == "tiktok":
    append "vertical 9:16, trendy aesthetic, gen-z appeal, vibrant and dynamic"
ELIF platform == "twitter":
    append "horizontal 16:9 or 1:1, clean and shareable, works with text overlay"
ELIF platform == "linkedin":
    append "professional, clean, corporate-appropriate, 1200x627 composition"
```

### Random Element Injection for Variety
- Maintain lists of style variants, color accents, props, backgrounds
- Randomly select 1-2 elements per generation to ensure visual diversity
- Example pools:
  - Backgrounds: "urban", "nature", "studio", "abstract", "home"
  - Lighting moods: "warm golden", "cool blue", "dramatic", "soft pastel", "neon"
  - Camera angles: "eye level", "low angle", "overhead", "Dutch angle"

### A/B Prompt Testing Framework
1. Define the control prompt (current best performer)
2. Create one variant changing a single element (style, lighting, composition)
3. Generate 3-5 outputs from each prompt
4. Score outputs on: quality (1-10), brand alignment (1-10), engagement prediction (1-10)
5. Promote winner to new control, iterate
6. Log all tests in `metadata/prompts.json` for institutional learning

---

## Video Prompt Patterns

### Runway Gen-3/Gen-4
- Describe motion explicitly: "camera slowly pans left to right", "subject walks toward camera"
- Scene transitions: "smooth dissolve from close-up to wide shot"
- Temporal descriptions: "begins with stillness, then bursts into motion"
- Camera movement vocabulary: pan, tilt, dolly, crane, orbit, push-in, pull-out, whip pan
- Example: "Cinematic slow-motion shot of coffee being poured into a ceramic mug, camera slowly pushing in, warm morning light from the right, steam rising, shallow depth of field, 24fps film grain"

### Higgsfield Soul
- Character description: specify gender, age range, ethnicity, expression, clothing
- Pose: "standing confidently", "sitting casually", "leaning forward engaged"
- Expression: "warm genuine smile", "thoughtful contemplation", "excited surprise"
- Style: reference photography styles for consistency
- Example: "Professional young woman in business casual, warm smile, confident posture, clean studio background, soft lighting"

### Kling/Pika
- Action-focused: emphasize what happens in the scene
- Short, clear descriptions of single actions work best
- Specify duration feel: "quick dynamic movement" vs "slow graceful motion"
- Example: "A hand reaches for a glowing product on a pedestal, dramatic lighting shifts from cool to warm as fingers make contact, particle effects emanate from the touch point"
