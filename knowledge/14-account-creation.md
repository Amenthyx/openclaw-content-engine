# Account Creation — Autonomous Signup, Verification & Onboarding

OpenClaw can create new accounts on websites autonomously using the browser tool. This document covers the general signup workflow, verification handling, CAPTCHA strategies, password management, and platform-specific flows.

---

## General Account Creation Workflow

### Step-by-Step Pattern
```
ACCOUNT CREATION:
├── 1. browser open <signup_url>
├── 2. browser snapshot → identify form fields (email, password, name, etc.)
├── 3. Generate secure password (see Password Generation below)
├── 4. browser fill --fields '[{"ref":"<email_ref>","value":"user@domain.com"},{"ref":"<password_ref>","value":"<generated_password>"}]'
├── 5. Fill remaining fields (name, username, DOB, etc.)
├── 6. browser snapshot → look for Terms checkbox
├── 7. browser click <terms_checkbox_ref>
├── 8. browser click <submit_button_ref>
├── 9. browser snapshot → check result:
│   ├── Success page → proceed to verification
│   ├── Error message → read error, fix, retry
│   └── CAPTCHA → notify user (see CAPTCHA section)
├── 10. Handle verification (email, phone, or both)
├── 11. Save credentials to ~/.openclaw/credentials.json
└── 12. Save browser session/cookies for future use
```

---

## Password Generation

Generate secure random passwords using exec:
```bash
# Generate a 24-character random password
exec openssl rand -base64 24 | tr -d '/+=' | head -c 24

# Generate with specific requirements (uppercase, lowercase, numbers, symbols)
exec python3 -c "
import secrets, string
chars = string.ascii_letters + string.digits + '!@#$%^&*'
password = ''.join(secrets.choice(chars) for _ in range(24))
print(password)
"
```

### Storing Credentials
After account creation, immediately save to `~/.openclaw/credentials.json`:
```bash
exec python3 -c "
import json
creds_path = '$HOME/.openclaw/credentials.json'
with open(creds_path) as f:
    creds = json.load(f)
creds['new_platform'] = {
    'email': 'user@domain.com',
    'password': 'GENERATED_PASSWORD',
    'username': 'chosen_username',
    '2fa_secret': '',
    'created_at': '2026-03-07',
    'recovery_codes': []
}
with open(creds_path, 'w') as f:
    json.dump(creds, f, indent=2)
print('Credentials saved.')
"
```

**Security rules:**
- Never log passwords to stdout or log files
- credentials.json should have restrictive permissions: `chmod 600 ~/.openclaw/credentials.json`
- Never commit credentials to git

---

## Email Verification Handling

Most signups require clicking a verification link in an email.

### Flow
```
EMAIL VERIFICATION:
├── 1. After signup, browser snapshot → look for "check your email" message
├── 2. Open email provider in a new tab:
│   │   browser open https://mail.google.com
│   │   (or https://outlook.live.com, https://mail.proton.me, etc.)
├── 3. Login to email if not already logged in
├── 4. browser snapshot → find the verification email
│   ├── Look for sender matching the platform name
│   ├── Look for subject lines like "Verify", "Confirm", "Welcome"
│   └── If not found, browser wait --timeout 30000 → snapshot again
├── 5. browser click <email_ref> → open the email
├── 6. browser snapshot → find the verification link/button
│   ├── Look for "Verify Email", "Confirm Account", "Click here"
│   └── Or extract the verification URL from the email body
├── 7. browser click <verify_button_ref>
├── 8. browser snapshot → confirm verification succeeded
└── 9. Return to the platform tab and continue onboarding
```

### Handling Delayed Emails
```bash
# Wait up to 2 minutes, checking every 15 seconds
# In practice: snapshot, check for email, if not found, wait and retry
```
```
RETRY LOOP (max 8 attempts, 15s apart):
├── browser reload
├── browser snapshot
├── Search for verification email
├── Found? → proceed
└── Not found? → wait 15s → retry
```

### Verification Code Emails
Some platforms send a 6-digit code instead of a link:
```
1. Open email, find code (usually a prominent 6-digit number)
2. Switch back to platform tab
3. browser type <code_input_ref> "123456"
4. browser click <verify_button_ref> or browser press Enter
```

---

## Phone Verification Strategies

Phone verification cannot be fully automated because it requires receiving an SMS.

### When Phone Verification Appears
```
PHONE VERIFICATION:
├── Is phone number already on file in credentials.json?
│   ├── YES → Enter it, then ASK user for the SMS code
│   └── NO → ASK user for phone number first
├── After entering phone number:
│   ├── Wait for user to provide the SMS verification code
│   ├── browser type <code_ref> "<code_from_user>"
│   └── browser click <verify_ref>
└── Log: phone verification was required for this platform
```

**Always notify the user immediately** when phone verification is needed. Do not wait or retry — the user must provide the code.

---

## CAPTCHA Handling

CAPTCHAs block automated flows. OpenClaw cannot solve them directly.

### Strategy
```
CAPTCHA DETECTED:
├── 1. browser screenshot → capture the CAPTCHA for context
├── 2. Notify user: "CAPTCHA encountered on [platform]. Please solve it."
├── 3. Options:
│   ├── A) User solves it in the browser session (if shared/VNC)
│   ├── B) Try the accessible alternative:
│   │   └── browser click <audio_captcha_ref> (if available)
│   ├── C) Try a different signup method:
│   │   └── "Sign up with Google" (may bypass CAPTCHA)
│   └── D) Wait and retry later (some CAPTCHAs are rate-limit triggered)
├── 4. After CAPTCHA is solved, browser snapshot → continue signup flow
└── 5. Log CAPTCHA occurrence for future reference
```

### CAPTCHA Avoidance Tips
- Use natural typing speed with small random delays between keystrokes
- Don't reload the signup page repeatedly
- Use "Sign in with Google/GitHub" SSO when available (fewer CAPTCHAs)
- Space out account creation attempts across different platforms

---

## Common Signup Form Patterns

### Social Media Platforms (Instagram, TikTok, X/Twitter)
```
TYPICAL FIELDS:
├── Email or phone number
├── Full name / Display name
├── Username (must be unique — if taken, try variations)
├── Password
├── Date of birth
├── CAPTCHA (common)
└── Email/phone verification

FLOW:
1. browser open https://www.instagram.com/accounts/emailsignup/
2. browser snapshot
3. Fill email, full name, username, password
4. browser click <Sign Up ref>
5. Handle DOB picker if prompted
6. Handle email verification code
```

### Developer Platforms (GitHub, GitLab, Vercel)
```
TYPICAL FIELDS:
├── Username
├── Email
├── Password
└── Email verification (code or link)

FLOW:
1. browser open https://github.com/signup
2. browser snapshot
3. Follow multi-step form (GitHub uses a step-by-step wizard)
4. Enter email → Continue → Enter password → Continue → Enter username → Continue
5. Solve CAPTCHA if presented
6. Enter email verification code
```

### AI Platforms (OpenAI, Anthropic, ElevenLabs, Runway)
```
TYPICAL FIELDS:
├── Email
├── Password (or passwordless via email magic link)
└── Email verification

PREFERRED METHOD:
├── "Continue with Google" (fastest, fewer steps, avoids CAPTCHA)
└── Falls back to email signup if Google SSO unavailable

FLOW:
1. browser open https://platform.ai/signup
2. browser snapshot
3. Look for "Continue with Google" button → click it
4. Handle Google OAuth flow (see Google SSO below)
5. Complete onboarding wizard (name, use case, etc.)
```

### Google SSO Flow (Used by Many Platforms)
```
1. browser click <Continue with Google ref>
2. browser snapshot → Google account picker or login page
3. If already logged into Google:
   └── browser click <account_ref> → authorized, redirect back
4. If not logged in:
   ├── browser type <email_ref> "user@gmail.com"
   ├── browser press Enter
   ├── browser wait --text "password"
   ├── browser type <password_ref> "<password>"
   ├── browser press Enter
   └── Handle 2FA if prompted
5. browser snapshot → may need to "Allow" permissions
6. browser click <Allow ref>
7. Redirected back to platform → account created
```

---

## 2FA Setup

When a platform offers 2FA during onboarding, set it up for security.

### TOTP Setup (Authenticator App)
```
2FA SETUP:
├── 1. Platform shows QR code or TOTP secret string
├── 2. browser snapshot → look for the secret key text
│   └── Usually displayed as "Can't scan? Enter this key manually: ABCD EFGH IJKL MNOP"
├── 3. Save the TOTP secret to credentials.json:
│   └── "2fa_secret": "ABCDEFGHIJKLMNOP"
├── 4. Generate a TOTP code to verify setup:
│   exec python3 -c "
│   import hmac, hashlib, struct, time, base64
│   secret = base64.b32decode('ABCDEFGHIJKLMNOP')
│   counter = int(time.time()) // 30
│   h = hmac.new(secret, struct.pack('>Q', counter), hashlib.sha1).digest()
│   o = h[-1] & 0x0F
│   code = str((struct.unpack('>I', h[o:o+4])[0] & 0x7FFFFFFF) % 1000000).zfill(6)
│   print(code)
│   "
├── 5. browser type <code_ref> "<generated_code>"
├── 6. browser click <Verify ref>
└── 7. Save recovery codes if provided:
    └── "recovery_codes": ["code1", "code2", "code3", ...]
```

### Generating TOTP Codes for Future Logins
```bash
# Use pyotp if available
exec python3 -c "
import pyotp
totp = pyotp.TOTP('ABCDEFGHIJKLMNOP')
print(totp.now())
"

# Or use the raw HMAC method above if pyotp not installed
```

---

## Session Saving After Account Creation

After successfully creating and verifying an account, persist the browser session:
```
1. browser cookies → save all cookies for the platform domain
2. Store cookies at ~/.openclaw/sessions/<platform>.cookies.json
3. Update credentials.json with the new account details
4. browser screenshot → save confirmation page as proof
5. Log account creation event to ~/.openclaw/logs/account_creation.log
```

### Cookie Export
```bash
# After login, export cookies for later restoration
exec browser cookies > ~/.openclaw/sessions/platform_cookies.json
```

### Cookie Import on Future Visits
```
browser cookies --set '<contents of saved cookies file>'
browser open https://platform.com/dashboard
browser snapshot → verify logged in
```

---

## Account Recovery & Password Reset

### Password Reset Flow
```
PASSWORD RESET:
├── 1. browser open https://platform.com/forgot-password
├── 2. browser snapshot
├── 3. browser type <email_ref> "user@domain.com"
├── 4. browser click <Submit ref>
├── 5. Go to email inbox (same flow as email verification)
├── 6. Find password reset email
├── 7. Click reset link
├── 8. browser snapshot → enter new password
├── 9. Generate new password (see Password Generation)
├── 10. browser type <new_password_ref> "<new_password>"
├── 11. browser type <confirm_password_ref> "<new_password>"
├── 12. browser click <Reset ref>
├── 13. Update credentials.json with new password
└── 14. Verify login works with new credentials
```

### Account Locked / Suspended
```
ACCOUNT ISSUE DETECTED:
├── "Account locked" → Try password reset flow
├── "Account suspended" → Notify user, log the issue, do not retry
├── "Unusual activity" → Complete security challenge if possible, else notify user
└── "Account disabled" → Notify user, suggest creating a new account
```

---

## Best Practices

1. **One account per platform** unless explicitly told otherwise
2. **Use the same email** across platforms when possible for simplicity
3. **Always save credentials immediately** after account creation — do not defer
4. **Screenshot every step** of account creation for audit trail
5. **Prefer SSO (Google/GitHub)** over email signup when available — fewer CAPTCHAs, fewer passwords
6. **Never reuse passwords** across platforms — generate unique ones
7. **Set up 2FA** whenever offered — save the TOTP secret for future automated logins
8. **Test the login** immediately after creation — verify the saved credentials work
