# Browser Automation — Using OpenClaw's Built-In Browser Tool

## Overview
OpenClaw has a built-in browser tool powered by Playwright. You control it through the `browser` tool — no external scripts needed. You can navigate, click, type, fill forms, take screenshots, download files, manage cookies, and more.

The browser runs Chrome/Chromium and is fully controllable by the agent during conversations.

---

## Core Browser Commands

### Starting & Status
```
browser start                    — Launch the browser
browser status                   — Check if browser is running
browser stop                     — Close the browser
```

### Navigation
```
browser open https://example.com        — Open URL in new tab
browser navigate https://example.com    — Navigate current tab to URL
browser tabs                            — List all open tabs
browser focus <targetId>                — Switch to a specific tab
browser close <targetId>                — Close a tab
```

### Reading the Page
```
browser snapshot                 — Get page content as AI-readable snapshot (with ref numbers)
browser snapshot --format aria   — Get accessibility tree
browser snapshot --labels        — Include visual labels on refs
browser screenshot               — Capture screenshot of current page
browser screenshot --full-page   — Full page screenshot
browser screenshot --ref 12      — Screenshot specific element
```

### Interacting with Elements
After taking a `snapshot`, each interactive element gets a **ref number**. Use these refs to interact:

```
browser click 12                 — Click element with ref 12
browser click 12 --double        — Double-click
browser type 23 "hello@email.com" — Type text into element ref 23
browser type 23 "text" --submit  — Type and press Enter
browser press Enter              — Press a key
browser press Tab                — Press Tab
browser hover 44                 — Hover over element
browser select 9 "Option A"     — Select dropdown option
browser scrollintoview 15       — Scroll element into view
browser drag 10 11              — Drag from ref 10 to ref 11
```

### Forms
```
browser fill --fields '[{"ref":"1","value":"user@email.com"},{"ref":"2","value":"mypassword"}]'
```

### File Upload & Download
```
browser upload /path/to/file.pdf          — Arm file upload for next file chooser
browser download 15 --save /path/out.png  — Click ref 15 and save download
browser waitfordownload                   — Wait for next download
```

### Cookies & Storage
```
browser cookies                          — Read all cookies
browser cookies --set '[{"name":"token","value":"abc","domain":".example.com"}]'
browser storage                          — Read localStorage
browser storage --set '{"key":"value"}'
```

### Dialogs
```
browser dialog --accept           — Accept next alert/confirm/prompt
browser dialog --dismiss          — Dismiss next dialog
```

### Advanced
```
browser evaluate --fn '(el) => el.textContent' --ref 7   — Run JS on element
browser console --level error     — Get console errors
browser requests                  — Get recent network requests
browser wait --text "Done"        — Wait for text to appear
browser wait --url "dashboard"    — Wait for URL to contain string
browser pdf                       — Save page as PDF
browser trace start/stop          — Record Playwright trace
```

---

## Login Workflow Pattern

Every platform login follows this pattern:

### Step 1: Navigate to login page
```
browser navigate https://chat.openai.com
browser snapshot
```

### Step 2: Read the snapshot, find the login elements (email field, password field, buttons)
The snapshot returns numbered refs like:
```
[1] textbox "Email address"
[2] button "Continue"
```

### Step 3: Fill and submit
```
browser type 1 "user@email.com"
browser click 2
browser snapshot
browser type 3 "mypassword"
browser click 4
```

### Step 4: Verify login succeeded
```
browser snapshot
```
Check if dashboard/home elements are visible.

### Step 5: Save cookies for next time
```
browser cookies
```
Save the cookies so you can restore the session later without logging in again.

---

## Platform Login Examples

### ChatGPT Login → Image Generation
```
1. browser navigate https://chat.openai.com
2. browser snapshot → find "Log in" button → browser click [ref]
3. browser snapshot → find email field → browser type [ref] "email"
4. browser click [continue ref]
5. browser snapshot → find password field → browser type [ref] "password"
6. browser click [submit ref]
7. browser wait --text "New chat" (or wait for chat input to appear)
8. browser snapshot → find message input
9. browser type [ref] "Generate an image: a sunset over mountains, photorealistic, 4K"
10. browser press Enter
11. browser wait --text "" (wait 30-60s for image)
12. browser snapshot → find generated image → browser screenshot --ref [img ref]
```

### ElevenLabs Login → Generate Voiceover
```
1. browser navigate https://elevenlabs.io/sign-in
2. browser snapshot → fill email, password → submit
3. browser navigate https://elevenlabs.io/app/speech-synthesis
4. browser snapshot → find voice dropdown → browser select [ref] "Rachel"
5. browser snapshot → find text area → browser type [ref] "Welcome to our product..."
6. browser snapshot → find Generate button → browser click [ref]
7. browser wait --text "Download" (wait for audio to render)
8. browser snapshot → find download button → browser download [ref] --save /path/voiceover.mp3
```

### Higgsfield Login → Avatar Generation
```
1. browser navigate https://platform.higgsfield.ai/login
2. browser snapshot → fill credentials → submit
3. Navigate to Soul section
4. browser snapshot → find prompt field → type avatar description
5. browser click Generate → wait for result
6. browser download [ref] --save /path/avatar.png
```

### Instagram Login → Post Content
```
1. browser navigate https://www.instagram.com/accounts/login/
2. browser snapshot → fill username, password → submit
3. browser wait --url "instagram.com" (wait for redirect to feed)
4. browser snapshot → find "New post" button → click
5. browser upload /path/to/image.jpg (arm file upload)
6. browser snapshot → click through Next/filters
7. browser snapshot → find caption field → type caption + hashtags
8. browser snapshot → find Share button → click
```

### Midjourney via Discord
```
1. browser navigate https://discord.com/login
2. browser snapshot → fill email, password → submit
3. Navigate to Midjourney bot DM
4. browser snapshot → find message input
5. browser type [ref] "/imagine prompt: beautiful landscape --ar 16:9 --v 6.1"
6. browser press Enter
7. Wait 60-90s, then browser snapshot to check for generated images
8. browser snapshot → find U1/U2/U3/U4 buttons → click to upscale
9. browser snapshot → find upscaled image → screenshot or download
```

---

## Session Persistence with Cookies

### Save session after login
```
browser cookies
```
Store the output. On next use, restore with:
```
browser cookies --set '[...saved cookies...]'
browser navigate https://platform.com
browser snapshot  → verify still logged in
```

If session expired (redirected to login page), re-login with credentials.

---

## Desktop Screenshots (via exec tool)

The `browser screenshot` command only captures the browser tab. To capture the **active window** or **full desktop**, use the `exec` tool:

### Using screenshot.sh helper
```
exec bash /home/node/.openclaw/workspace/screenshot.sh /tmp/screenshot.png --window
exec bash /home/node/.openclaw/workspace/screenshot.sh /tmp/screenshot.png --full
exec bash /home/node/.openclaw/workspace/screenshot.sh /tmp/screenshot.png --region
```

### Using scrot directly (Linux/Docker)
```
exec scrot -u /tmp/active_window.png          — Active window only
exec scrot /tmp/full_screen.png               — Full screen
exec scrot -s /tmp/selected_area.png          — Select region
```

### Using ImageMagick import (alternative)
```
exec import -window root /tmp/screen.png      — Full screen
exec import -window $(xdotool getactivewindow) /tmp/win.png  — Active window
```

### When to use which
- **User asks "take a screenshot"** → use `exec` with screenshot.sh (captures desktop)
- **You need to see browser page content** → use `browser screenshot`
- **You need to capture something outside the browser** → use `exec` with screenshot.sh

---

## Exec Tool — Running Commands

The `exec` tool lets you run any shell command. This is essential for:

```
exec ffmpeg -i input.mp4 -c:v libx264 output.mp4           — Video processing
exec convert image.png -resize 1080x1080 resized.png        — Image resize/convert
exec curl -L -o /tmp/file.jpg "https://example.com/img.jpg" — Download files
exec python3 -c "from PIL import Image; ..."                — Python image processing
exec jq '.credentials.chatgpt' ~/.openclaw/credentials.json — Read credentials
exec ls -la /home/node/.openclaw/workspace/                 — List workspace files
```

**IMPORTANT:** You have full shell access via `exec`. Never say you cannot run commands or scripts.

---

## Best Practices

### Human-Like Behavior
- Wait 1-3 seconds between actions (don't rush)
- Take snapshots before every interaction to see current state
- Don't click elements you can't see — use `scrollintoview` first
- Handle unexpected popups (cookie banners, notifications) by dismissing them

### Error Recovery
- If element not found: take new snapshot, the page may have updated
- If click doesn't work: try `scrollintoview` first, then click
- If page is loading: use `browser wait --text "expected text"`
- If login fails: check credentials, try again once
- If CAPTCHA appears: notify user, wait for manual solve

### Multiple Platforms
- Open each platform in a separate tab
- Use `browser tabs` to list them
- Use `browser focus <targetId>` to switch between platforms
- Close tabs when done to save memory

### Downloading Generated Content
- Always download immediately — URLs may expire
- Use `browser download [ref]` for download buttons
- Use `browser screenshot --ref [ref]` to capture images directly from the page
- For images without download buttons: right-click image → save, or extract URL from snapshot and use `browser evaluate`
