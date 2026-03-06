# Browser Automation — Core Operating Method

## Overview
Browser automation is the PRIMARY and ONLY method OpenClaw uses to interact with external platforms. There are no API keys — everything happens through the browser, exactly as a human would do it.

## Browser Environment

ClawBot's Docker container provides:
```
- Chromium browser (full, not headless)
- Xvfb virtual display at :99 (1920x1080x24)
- x11vnc for VNC access (port 5900)
- noVNC web interface (port 6080) — user can watch/interact
- Fluxbox window manager
- Persistent session storage at /home/node/.openclaw/sessions/
```

The user can always see what ClawBot is doing by opening http://localhost:6080 in their browser.

## Browser Automation Framework

### Playwright (Recommended)
```javascript
const { chromium } = require('playwright');

// Launch browser on the virtual display
const browser = await chromium.launch({
  headless: false,  // Use real browser on Xvfb
  executablePath: '/usr/bin/chromium',
  args: ['--no-sandbox', '--disable-dev-shm-usage']
});

// Load saved session (skip login if cookies are valid)
const context = await browser.newContext({
  storageState: '/home/node/.openclaw/sessions/chatgpt-session.json'
});

const page = await context.newPage();
```

### Session Save/Restore Pattern
```javascript
// After successful login — save session
await context.storageState({ path: `/home/node/.openclaw/sessions/${platform}-session.json` });

// Before next operation — restore session
const context = await browser.newContext({
  storageState: `/home/node/.openclaw/sessions/${platform}-session.json`
});

// Check if session is still valid
await page.goto('https://platform.com/dashboard');
const isLoggedIn = await page.locator('.user-avatar').isVisible({ timeout: 5000 }).catch(() => false);

if (!isLoggedIn) {
  // Session expired — re-login
  await loginToPlatform(page, credentials);
  await context.storageState({ path: sessionPath });
}
```

## Human-Like Behavior Patterns

### Typing
```javascript
// Type like a human — random delays between keystrokes
async function humanType(page, selector, text) {
  await page.click(selector);
  for (const char of text) {
    await page.keyboard.type(char, { delay: 50 + Math.random() * 100 });
  }
}
```

### Mouse Movement
```javascript
// Move mouse naturally before clicking
async function humanClick(page, selector) {
  const element = await page.locator(selector);
  const box = await element.boundingBox();
  // Move to a random point within the element
  const x = box.x + box.width * (0.3 + Math.random() * 0.4);
  const y = box.y + box.height * (0.3 + Math.random() * 0.4);
  await page.mouse.move(x, y, { steps: 10 + Math.floor(Math.random() * 10) });
  await page.waitForTimeout(200 + Math.random() * 300);
  await page.mouse.click(x, y);
}
```

### Random Delays
```javascript
// Wait a human-like amount of time between actions
async function humanDelay(page, minMs = 1000, maxMs = 3000) {
  const delay = minMs + Math.random() * (maxMs - minMs);
  await page.waitForTimeout(delay);
}
```

### Scroll Naturally
```javascript
// Scroll down gradually, like reading
async function humanScroll(page, distance = 500) {
  const steps = 5 + Math.floor(Math.random() * 5);
  const stepSize = distance / steps;
  for (let i = 0; i < steps; i++) {
    await page.mouse.wheel(0, stepSize + Math.random() * 20);
    await page.waitForTimeout(100 + Math.random() * 200);
  }
}
```

## Platform-Specific Browser Workflows

### ChatGPT Image Generation (Detailed)
```javascript
async function generateImageChatGPT(page, prompt) {
  // Navigate to ChatGPT
  await page.goto('https://chat.openai.com');
  await humanDelay(page, 2000, 4000);

  // Type prompt in message box
  const input = page.locator('#prompt-textarea, textarea[placeholder]');
  await humanType(page, input, `Generate an image: ${prompt}`);
  await humanDelay(page, 500, 1000);

  // Send message
  await page.keyboard.press('Enter');

  // Wait for image to appear (up to 60 seconds)
  const image = page.locator('img[alt*="Generated"], img[src*="oaidalleapi"]');
  await image.waitFor({ timeout: 60000 });
  await humanDelay(page, 1000, 2000);

  // Get image URL
  const src = await image.getAttribute('src');

  // Download image
  const response = await page.request.get(src);
  const buffer = await response.body();
  fs.writeFileSync(`/home/node/.openclaw/workspace/generated-image-${Date.now()}.png`, buffer);

  return src;
}
```

### Instagram Post (Detailed)
```javascript
async function postToInstagram(page, imagePath, caption) {
  await page.goto('https://www.instagram.com');
  await humanDelay(page, 2000, 4000);

  // Click create post button (+ icon)
  await humanClick(page, '[aria-label="New post"]');
  await humanDelay(page, 1000, 2000);

  // Upload file
  const fileInput = page.locator('input[type="file"]');
  await fileInput.setInputFiles(imagePath);
  await humanDelay(page, 2000, 4000);

  // Click "Next" through crop/filter screens
  await humanClick(page, 'button:has-text("Next")');
  await humanDelay(page, 1000, 2000);
  await humanClick(page, 'button:has-text("Next")');
  await humanDelay(page, 1000, 2000);

  // Enter caption
  const captionInput = page.locator('[aria-label="Write a caption..."]');
  await humanType(page, captionInput, caption);
  await humanDelay(page, 1000, 2000);

  // Share
  await humanClick(page, 'button:has-text("Share")');
  await page.waitForTimeout(5000);
}
```

### File Download Pattern
```javascript
// Download any generated file from a platform
async function downloadFile(page, downloadSelector, outputPath) {
  // Set up download listener
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.click(downloadSelector)
  ]);

  // Save to workspace
  await download.saveAs(outputPath);
  return outputPath;
}

// Alternative: download from image URL
async function downloadFromUrl(page, imageUrl, outputPath) {
  const response = await page.request.get(imageUrl);
  const buffer = await response.body();
  fs.writeFileSync(outputPath, buffer);
  return outputPath;
}
```

## Multi-Platform Pipeline (Browser)

### Full Video Pipeline Example
```
1. Login to ChatGPT → generate script (text conversation)
2. Login to ChatGPT → generate scene images (image generation)
3. Download all images to local workspace
4. Login to ElevenLabs → generate voiceover from script → download MP3
5. Login to Higgsfield → upload image + audio → generate lip-sync video → download
6. FFmpeg locally → merge clips, add transitions, subtitles, music
7. Login to Instagram → upload final video as Reel with caption
8. Login to TikTok → upload final video with adapted caption
9. Login to YouTube → upload as Short with metadata
```

Each step uses the browser except FFmpeg (runs locally).

## CAPTCHA Protocol

```
1. CAPTCHA detected (hCaptcha, reCAPTCHA, Cloudflare challenge)
2. PAUSE all automation immediately
3. NOTIFY user: "CAPTCHA on [platform] — solve via VNC at http://localhost:6080"
4. WAIT for user to solve (check every 5 seconds if CAPTCHA is gone)
5. RESUME automation
6. SLOW DOWN: increase delays by 2x for next 10 minutes
```

## Error Recovery

| Error | Action |
|-------|--------|
| Session expired | Re-login with credentials, save new session |
| Element not found | Wait 5s, retry. If 3 failures, page may have changed — notify user |
| CAPTCHA | Pause, notify user, wait for VNC solve |
| Rate limited | Wait 5-15 minutes, then retry with slower pace |
| Page crash | Restart browser, restore session, retry |
| Download failed | Retry download 3 times, then try screenshot as fallback |
| Login failed | Check credentials, retry once. If still fails, notify user |
| 2FA required | Use TOTP secret if available, otherwise ask user |

## Browser Resource Management

- Maximum 3 tabs open simultaneously (prevent memory issues)
- Close tabs after completing each platform's task
- Clear browser cache weekly to prevent storage bloat
- Restart browser every 50 operations for stability
- Monitor memory usage — restart if Chromium exceeds 2GB
