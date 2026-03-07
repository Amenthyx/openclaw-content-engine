# Autonomous Operations — Heartbeat, Scheduling & Proactive Execution

OpenClaw can operate as a fully autonomous agent that runs continuously, monitors the world, and takes action without waiting for user prompts. This document covers the heartbeat scheduler, background monitoring, autonomous decision-making, and self-healing patterns.

---

## Heartbeat Scheduler

The heartbeat is the core loop that keeps OpenClaw alive between user interactions. It wakes up on a schedule, checks for pending tasks, and executes them.

### Configuration

Store heartbeat config at `~/.openclaw/heartbeat.json`:
```json
{
  "enabled": true,
  "interval_minutes": 15,
  "wake_triggers": ["schedule", "file_change", "webhook", "email"],
  "quiet_hours": { "start": "23:00", "end": "07:00", "timezone": "UTC" },
  "max_consecutive_runs": 10,
  "cooldown_after_max_minutes": 30
}
```

### Cron-Based Scheduling

Set up system-level scheduling to trigger the heartbeat:
```bash
# Linux/macOS — crontab entry (every 15 minutes)
*/15 * * * * cd ~/.openclaw && /usr/local/bin/openclaw heartbeat >> ~/.openclaw/logs/heartbeat.log 2>&1

# Windows — Task Scheduler via PowerShell
schtasks /create /tn "OpenClaw Heartbeat" /tr "openclaw heartbeat" /sc minute /mo 15
```

### Heartbeat Loop Logic
```
HEARTBEAT TICK:
├── 1. Load ~/.openclaw/heartbeat.json
├── 2. Check quiet hours — if inside, skip and sleep
├── 3. Load ~/.openclaw/task_queue.json
├── 4. For each pending task (sorted by priority):
│   ├── Check if scheduled time has arrived
│   ├── Check preconditions (e.g., file exists, URL reachable)
│   ├── Execute task pipeline
│   ├── Log result to ~/.openclaw/logs/
│   └── Update task status (completed / failed / retry)
├── 5. Run proactive monitors (see below)
├── 6. Save state to ~/.openclaw/session_state.json
└── 7. Sleep until next tick
```

---

## Task Queue

All scheduled and deferred tasks live in `~/.openclaw/task_queue.json`:
```json
[
  {
    "id": "task_001",
    "type": "publish_post",
    "status": "pending",
    "priority": 1,
    "scheduled_at": "2026-03-07T09:00:00Z",
    "retries": 0,
    "max_retries": 3,
    "payload": {
      "platform": "instagram",
      "content_path": "~/.openclaw/assets/posts/march-7-reel.mp4",
      "caption": "Morning vibes only."
    },
    "created_at": "2026-03-06T22:00:00Z"
  }
]
```

### Managing the Queue via exec
```bash
# List pending tasks
exec cat ~/.openclaw/task_queue.json | jq '[.[] | select(.status == "pending")]'

# Count tasks by status
exec cat ~/.openclaw/task_queue.json | jq 'group_by(.status) | map({status: .[0].status, count: length})'

# Add a task programmatically
exec cat ~/.openclaw/task_queue.json | jq '. + [{"id":"task_new","type":"check_analytics","status":"pending","priority":2,"scheduled_at":"2026-03-07T18:00:00Z","retries":0,"max_retries":2,"payload":{}}]' > /tmp/tq.json && mv /tmp/tq.json ~/.openclaw/task_queue.json
```

---

## Proactive Monitoring Patterns

### File Watching
Monitor a folder for new files (e.g., user drops an image into an inbox folder):
```bash
# Check for new files in the inbox folder
exec find ~/.openclaw/inbox/ -type f -newer ~/.openclaw/.last_check -print

# After processing, update the timestamp
exec touch ~/.openclaw/.last_check
```

When new files are detected:
```
NEW FILE DETECTED in inbox/:
├── Image file (.png, .jpg) -> Queue "optimize and post" task
├── Video file (.mp4, .mov) -> Queue "process and publish" task
├── Text file (.txt, .md) -> Queue "generate content from brief" task
└── Audio file (.mp3, .wav) -> Queue "transcribe and create post" task
```

### Email Inbox Monitoring
Log into email via browser, check for actionable messages:
```
browser open https://mail.google.com
browser snapshot
→ Look for unread emails matching filters:
  - Subject contains "content request" -> Parse and queue task
  - Subject contains "approval" -> Mark content as approved, proceed to publish
  - From known client addresses -> Flag for priority processing
```

### Webhook Monitoring
Run a lightweight local webhook listener:
```bash
# Start a simple webhook receiver (Python)
exec python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers['Content-Length'])
        data = json.loads(self.rfile.read(length))
        with open('$HOME/.openclaw/webhook_inbox.json', 'a') as f:
            f.write(json.dumps(data) + '\n')
        self.send_response(200)
        self.end_headers()

HTTPServer(('0.0.0.0', 9876), Handler).serve_forever()
" &
```

### Calendar / Schedule Monitoring
```
browser open https://calendar.google.com
browser snapshot
→ Read today's events
→ Cross-reference with content calendar at ~/.openclaw/content_calendar.json
→ Queue any content that needs to go out today
```

---

## Autonomous Decision-Making Framework

The agent must decide: **act autonomously** or **ask the user**?

### Act Autonomously When:
- Task is already approved and scheduled in the queue
- Action is reversible (draft, local file operation, analytics check)
- Task matches a known pipeline with no ambiguous parameters
- Retry of a previously-approved task that failed
- Routine monitoring (checking analytics, downloading reports)
- File organization and cleanup of temp files

### Ask the User When:
- Publishing to a live audience for the first time on a new platform
- Content involves brand voice decisions not covered by existing guidelines
- Spending money (ad budgets, premium feature purchases)
- CAPTCHA appears and cannot be bypassed
- Account security events (password change prompts, 2FA challenges)
- Task has failed max_retries times — escalate
- Ambiguous instructions that could produce very different outcomes

### Decision Tree
```
INCOMING TASK:
├── Is it scheduled and pre-approved? -> ACT
├── Is it a retry of an approved task? -> ACT
├── Is it reversible (draft/local)? -> ACT
├── Does it match a known pipeline exactly? -> ACT
├── Does it involve publishing live? -> ASK (unless pre-approved)
├── Does it involve money? -> ASK
├── Is it ambiguous? -> ASK
└── Has it failed too many times? -> ESCALATE to user
```

---

## Multi-Step Pipeline Orchestration

Chain multiple tools together without user prompts. Each step feeds into the next.

### Pipeline Execution Pattern
```
PIPELINE: "morning_content_batch"
├── Step 1: Read content calendar -> get today's planned posts
├── Step 2: For each post:
│   ├── Generate image (browser -> ChatGPT/DALL-E)
│   ├── Download image to ~/.openclaw/assets/
│   ├── Generate caption (exec -> local LLM or browser -> ChatGPT)
│   ├── Resize for each platform (exec -> FFmpeg/ImageMagick)
│   └── Queue publish tasks with scheduled times
├── Step 3: Execute publish queue in order
├── Step 4: Verify each post went live (browser -> check platform)
└── Step 5: Log results and send summary to user
```

### Inter-Step Data Passing
Store intermediate results in `~/.openclaw/pipeline_state/<pipeline_id>.json`:
```json
{
  "pipeline_id": "morning_batch_20260307",
  "current_step": 3,
  "started_at": "2026-03-07T07:00:00Z",
  "steps": {
    "1": { "status": "completed", "output": { "posts_planned": 4 } },
    "2": { "status": "completed", "output": { "images_generated": 4, "paths": ["..."] } },
    "3": { "status": "in_progress", "output": null }
  }
}
```

---

## Session Continuity

Restore context after agent restart so work is not lost.

### State Persistence
Before shutdown or at each heartbeat tick, save:
```json
// ~/.openclaw/session_state.json
{
  "last_active": "2026-03-07T14:30:00Z",
  "active_pipeline": "morning_batch_20260307",
  "pipeline_step": 3,
  "browser_sessions": {
    "instagram": { "logged_in": true, "last_verified": "2026-03-07T07:05:00Z" },
    "chatgpt": { "logged_in": true, "last_verified": "2026-03-07T07:02:00Z" }
  },
  "pending_user_questions": [],
  "last_completed_task": "task_042"
}
```

### Restoration on Wake
```
AGENT WAKE:
├── 1. Read ~/.openclaw/session_state.json
├── 2. Check if active_pipeline exists and is incomplete
│   └── YES -> Resume from pipeline_step
├── 3. Check browser_sessions — re-login if sessions expired
├── 4. Check pending_user_questions — present any to user
├── 5. Load task_queue.json — process due tasks
└── 6. Continue normal heartbeat loop
```

---

## Error Recovery & Fallback Strategies

### Retry Strategy
```
ON TASK FAILURE:
├── retries < max_retries?
│   ├── YES:
│   │   ├── Wait (exponential backoff: 2^retries * 30 seconds)
│   │   ├── Increment retry counter
│   │   └── Re-execute task
│   └── NO:
│       ├── Mark task as "failed"
│       ├── Log full error to ~/.openclaw/logs/errors/
│       └── Notify user with error summary
```

### Self-Healing Patterns
```bash
# Browser crashed -> restart it
exec browser status
# If not running:
exec browser start

# Login session expired -> re-authenticate
browser open https://platform.com/dashboard
browser snapshot
# If redirected to login page -> run login flow from 01-platform-authentication.md

# Disk space low -> clean up temp files
exec df -h ~/.openclaw/ | tail -1
exec find ~/.openclaw/tmp/ -type f -mtime +7 -delete
exec find ~/.openclaw/assets/drafts/ -type f -mtime +30 -delete

# Network down -> wait and retry
exec ping -c 1 google.com > /dev/null 2>&1 && echo "online" || echo "offline"
# If offline, back off 60s and check again
```

### Fallback Chains
```
IMAGE GENERATION FAILED:
├── Try 1: ChatGPT/DALL-E (browser)
├── Try 2: Stability AI (browser)
├── Try 3: Midjourney via Discord (browser)
└── Try 4: Use placeholder image + notify user

PUBLISHING FAILED:
├── Try 1: Direct browser upload
├── Try 2: Mobile web version of platform
├── Try 3: Save as draft on platform
└── Try 4: Save locally + notify user to publish manually
```

---

## Example Autonomous Workflows

### Morning Routine (Daily, 7:00 AM)
```
1. Check content calendar for today's posts
2. Generate all visual assets (images, thumbnails)
3. Write captions for each platform
4. Schedule posts at optimal times (from analytics data)
5. Check yesterday's post performance
6. Generate analytics summary
7. Send daily briefing to user (Telegram/email)
```

### Inbox Processing (Every 15 minutes)
```
1. Check ~/.openclaw/inbox/ for new files
2. Check email for content requests
3. Check webhook_inbox.json for API triggers
4. For each new item:
   ├── Classify content type
   ├── Match to appropriate pipeline
   ├── Queue task with appropriate priority
   └── Send acknowledgment if from external source
```

### Scheduled Post Publishing (On schedule)
```
1. Load task from queue where type = "publish_post" and scheduled_at <= now
2. Read content from payload path
3. Open target platform in browser
4. Login if needed
5. Navigate to post creation
6. Upload media, enter caption, set visibility
7. Publish
8. Verify post is live (snapshot the published page)
9. Save published URL to task log
10. Move to next scheduled post
```

### Weekly Analytics Report (Sundays, 8:00 PM)
```
1. Login to each active platform
2. Navigate to analytics dashboard
3. Screenshot key metrics
4. Extract numbers (followers, engagement, reach)
5. Compare to last week's data from ~/.openclaw/analytics/
6. Generate summary report with trends
7. Save report to ~/.openclaw/reports/
8. Send to user via preferred channel
```
