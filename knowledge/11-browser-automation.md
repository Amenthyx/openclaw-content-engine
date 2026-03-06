# Browser Automation for Platform Access

## Overview
When API access is unavailable or insufficient, OpenClaw can use browser automation to interact with platforms directly. This knowledge covers login flows, navigation patterns, and content management via browser.

## Browser Login Patterns

### General Login Flow
```
1. Navigate to login page
2. Fill email/username field
3. Fill password field
4. Click submit
5. Handle 2FA if prompted (TOTP, SMS, email verification)
6. Verify successful login (check for dashboard/home element)
7. Store session cookies for reuse
```

### Platform-Specific Login

#### ChatGPT (chat.openai.com)
- Login URL: `https://chat.openai.com/auth/login`
- Click "Log in" → Enter email → Enter password → Handle 2FA
- Session persistence: cookies valid ~2 weeks
- Image generation: navigate to chat, send prompt with "generate an image of..."
- Download generated images: right-click → save, or extract from `<img>` src
- DALL-E via ChatGPT: use the chat interface when API quota is exhausted

#### Higgsfield (platform.higgsfield.ai)
- Login URL: `https://platform.higgsfield.ai/login`
- API preferred, but browser needed for:
  - Avatar management (upload reference photos)
  - Template browsing and selection
  - Account settings and billing

#### Midjourney (discord.com)
- No direct API — browser/Discord bot is the primary interface
- Login to Discord web: `https://discord.com/login`
- Navigate to Midjourney server or DM the bot
- Type `/imagine prompt: [your prompt]`
- Wait for generation (watch for bot response)
- Click U1-U4 to upscale, V1-V4 for variations
- Download: click image → "Open in browser" → save

#### Canva (canva.com)
- Login URL: `https://www.canva.com/login`
- Template search and customization via browser
- Export designs in various formats
- Bulk creation with brand kit

#### Runway ML (app.runwayml.com)
- Login URL: `https://app.runwayml.com/login`
- API preferred, browser for:
  - Gen-4 features not yet in API
  - Asset library management
  - Project organization

### Session Management
- Store cookies in encrypted local storage
- Check session validity before each operation
- Auto-refresh expired sessions
- Handle "session expired" redirects gracefully
- Support multiple accounts per platform

### 2FA Handling
- **TOTP (Authenticator apps)**: Store TOTP secret, generate codes programmatically
- **SMS**: Cannot automate — prompt user for code
- **Email**: Check email via IMAP/API for verification codes
- **Security keys**: Cannot automate — prompt user

## Content Creation via Browser

### ChatGPT Image Generation (Browser Mode) — PRIMARY FREE OPTION
ChatGPT via browser is a key image generation channel because it provides DALL-E access
without consuming API credits. ClawBot should use this when:
- No OPENAI_API_KEY is set
- API quota is exhausted
- User wants to minimize costs
- Generating multiple iterations (cheaper via browser)

```
1. Open browser → navigate to https://chat.openai.com
2. Login (session cookies should persist)
3. Start new conversation or use existing
4. Send: "Generate an image: [detailed prompt with style, lighting, composition details]"
5. Wait for DALL-E generation (typically 10-30 seconds)
6. Right-click generated image → Save As (or extract src URL from DOM)
7. If quality insufficient, send: "Regenerate with [specific adjustments]"
8. For variations: "Create 3 variations of this image with [differences]"
9. For edits: "Edit this image to [change description]" (DALL-E edit mode)
```

Tips for ChatGPT browser image gen:
- Be extremely specific in prompts — ChatGPT may simplify your prompt otherwise
- Ask for "exactly as described, no changes" to prevent ChatGPT from modifying your prompt
- Request specific aspect ratios: "Generate in portrait 9:16 aspect ratio"
- For batch work: keep one conversation per project/brand for style consistency
- Download images immediately — they may expire from ChatGPT's CDN

### Midjourney Workflow (via Discord)
```
1. Open Discord, navigate to Midjourney bot DM or server
2. Type: /imagine prompt: [your detailed prompt] --ar 9:16 --v 6.1 --s 750
3. Wait ~60s for initial 4-grid generation
4. Select best result: click U1, U2, U3, or U4 (upscale)
5. For variations: click V1-V4
6. Download upscaled image
7. Optional: /describe [image] for reverse-engineering prompts
```

### Canva Design Automation
```
1. Login to Canva
2. Search templates by category/keyword
3. Select template matching brand style
4. Customize: replace text, images, colors
5. Apply brand kit (colors, fonts, logos)
6. Export: PNG for images, MP4 for videos, PDF for documents
7. Download or publish directly
```

## Anti-Detection Best Practices
- Use realistic browser fingerprints
- Randomize timing between actions (human-like delays)
- Rotate user agents periodically
- Handle CAPTCHAs: pause and prompt user, or use solving services
- Respect rate limits — don't automate faster than human speed
- Use residential proxies if IP blocks occur

## Cookie & Session Storage
```json
{
  "platform": "chatgpt",
  "cookies": [
    {
      "name": "__Secure-next-auth.session-token",
      "value": "...",
      "domain": ".chat.openai.com",
      "expires": "2026-03-20T00:00:00Z"
    }
  ],
  "lastLogin": "2026-03-06T04:00:00Z",
  "sessionValid": true
}
```

## Error Recovery
- **Login failed**: check credentials, handle password change, retry
- **CAPTCHA**: pause workflow, notify user, wait for manual solve
- **Rate limited**: slow down, wait, retry with longer delays
- **Page structure changed**: flag for prompt/selector update
- **Network error**: retry with backoff, switch network if needed
