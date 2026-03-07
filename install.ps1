# ============================================================================
# OpenClaw Fully Autonomous Agent — Windows PowerShell Installer
# Sets up a fully autonomous agent with browser control, system access,
# account creation, heartbeat scheduler, multi-channel gateway, and more.
# Run: powershell -ExecutionPolicy Bypass -File install.ps1
# ============================================================================
$ErrorActionPreference = "Stop"

function Log($msg)  { Write-Host "[Content-Engine] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[Content-Engine] $msg" -ForegroundColor Yellow }
function Err($msg)  { Write-Host "[Content-Engine] $msg" -ForegroundColor Red }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KnowledgeDir = Join-Path $ScriptDir "knowledge"
$SkillDir = Join-Path $ScriptDir "skills\content-engine"
$CredsTemplate = Join-Path $ScriptDir "credentials-template.json"

$InstallMode = ""
$OpenClawHome = ""
$ContainerName = ""
$OcBin = ""
$AgentName = ""
$AgentEmoji = ""
$OwnerName = ""
$AutonomyLevel = "1"
$CommStyle = "concise"
$WorkingHours = "24/7"
$EnableHeartbeat = "true"
$HeartbeatInterval = "15"
$NotifyChannel = "telegram"
$ChannelConfigs = @()

# ============================================================================
# Find openclaw binary
# ============================================================================
function Find-OpenClaw {
    # 1. PATH
    $found = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($found) { $script:OcBin = $found.Source; return $true }

    # 2. npx cache
    $npxBase = Join-Path $env:LOCALAPPDATA "npm-cache\_npx"
    if (Test-Path $npxBase) {
        $bins = Get-ChildItem -Path $npxBase -Recurse -Filter "openclaw.cmd" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($bins) { $script:OcBin = $bins.FullName; return $true }
    }

    # 3. Global npm
    $npmGlobal = Join-Path $env:APPDATA "npm\openclaw.cmd"
    if (Test-Path $npmGlobal) { $script:OcBin = $npmGlobal; return $true }

    # 4. Roaming npm
    $npmRoaming = Join-Path $env:APPDATA "npm\openclaw"
    if (Test-Path $npmRoaming) { $script:OcBin = $npmRoaming; return $true }

    return $false
}

# ============================================================================
# Run openclaw config commands
# ============================================================================
function Oc-Config {
    param([string[]]$Args)
    if ($InstallMode -eq "local" -and $OcBin) {
        try { & $OcBin config @Args 2>$null } catch {}
    } elseif ($InstallMode -eq "docker") {
        try { docker exec -u node $ContainerName openclaw config @Args 2>$null } catch {}
    }
}

function Oc-Cmd {
    param([string[]]$Args)
    if ($InstallMode -eq "local" -and $OcBin) {
        try { & $OcBin @Args 2>$null } catch {}
    } elseif ($InstallMode -eq "docker") {
        try { docker exec -u node $ContainerName openclaw @Args 2>$null } catch {}
    }
}

# ============================================================================
# Detect installations
# ============================================================================
function Detect-Installations {
    Write-Host ""
    Log "Scanning for OpenClaw installations..."
    Write-Host ""

    $foundLocal = $false
    $foundDocker = $false
    $localPath = ""
    $dockerContainers = @()

    # Check candidate paths
    $candidates = @(
        (Join-Path $env:USERPROFILE ".openclaw"),
        (Join-Path $env:APPDATA "openclaw"),
        "C:\Users\$env:USERNAME\.openclaw"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c -PathType Container) {
            $localPath = $c
            $foundLocal = $true
            break
        }
    }

    # Find binary
    if (Find-OpenClaw) {
        Log "  Binary: $OcBin"
    } else {
        Warn "  openclaw binary not found"
    }

    # Docker
    $dockerAvailable = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
    if ($dockerAvailable) {
        try {
            $dockerContainers = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -match "claw" }
            if ($dockerContainers) { $foundDocker = $true }
        } catch {}
    }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  OpenClaw Content Engine Installer" -ForegroundColor Cyan
    Write-Host "  OS: Windows | PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Detected:" -NoNewline; Write-Host ""

    if ($foundLocal) { Write-Host "  [LOCAL]   $localPath" -ForegroundColor Green }
    if ($foundDocker) {
        Write-Host "  [DOCKER]  Containers:" -ForegroundColor Green
        foreach ($n in $dockerContainers) { Write-Host "            - $n" }
    }
    if (-not $foundLocal -and -not $foundDocker) {
        Write-Host "  No OpenClaw installation detected." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Where do you want to install?"
    Write-Host ""
    Write-Host "  1) Local install"
    if ($foundLocal) { Write-Host "     -> $localPath" } else { Write-Host "     -> $env:USERPROFILE\.openclaw" }
    Write-Host ""
    Write-Host "  2) Docker container"
    if ($foundDocker) { Write-Host "     -> $($dockerContainers[0])" } else { Write-Host "     -> Specify name" }
    Write-Host ""
    Write-Host "  3) Custom path"
    Write-Host ""

    while ($true) {
        $choice = Read-Host "  Choose [1/2/3]"
        switch ($choice) {
            "1" {
                $script:InstallMode = "local"
                $script:OpenClawHome = if ($localPath) { $localPath } else { Join-Path $env:USERPROFILE ".openclaw" }
                break
            }
            "2" {
                if (-not $dockerAvailable) { Err "Docker not installed."; continue }
                $script:InstallMode = "docker"
                if ($foundDocker) {
                    $default = $dockerContainers[0]
                    $cn = Read-Host "  Container [$default]"
                    $script:ContainerName = if ($cn) { $cn } else { $default }
                } else {
                    $script:ContainerName = Read-Host "  Container name"
                    if (-not $script:ContainerName) { Err "Required."; continue }
                }
                $running = docker ps --format '{{.Names}}' 2>$null
                if ($running -notcontains $script:ContainerName) { Err "'$($script:ContainerName)' not running."; continue }
                break
            }
            "3" {
                $cp = Read-Host "  OpenClaw config path"
                if (-not $cp) { Err "Required."; continue }
                $script:InstallMode = "local"
                $script:OpenClawHome = $cp
                break
            }
            default { Warn "Enter 1, 2, or 3." }
        }
        if ($script:InstallMode) { break }
    }

    Write-Host ""
    if ($InstallMode -eq "local") { Log "Mode: LOCAL -> $OpenClawHome" }
    else { Log "Mode: DOCKER -> $ContainerName" }
    Write-Host ""

    # --- Agent Identity ---
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Agent Identity" -ForegroundColor White
    Write-Host ""
    Write-Host "  This installer sets up a fully autonomous agent that can:"
    Write-Host "  - Browse the web, log in, create accounts"
    Write-Host "  - Control your machine (files, apps, clipboard)"
    Write-Host "  - Run scheduled tasks (heartbeat) 24/7"
    Write-Host "  - Communicate across multiple channels"
    Write-Host "  - Create content and publish to social media"
    Write-Host ""
    $nameInput = Read-Host "  Agent name [OpenClaw]"
    $script:AgentName = if ($nameInput) { $nameInput } else { "OpenClaw" }

    $emojiInput = Read-Host "  Agent emoji [🤖]"
    $script:AgentEmoji = if ($emojiInput) { $emojiInput } else { "🤖" }

    $ownerInput = Read-Host "  Your name (agent's owner) []"
    $script:OwnerName = $ownerInput

    Write-Host ""
    Log "Agent: $AgentEmoji $AgentName"
    Write-Host ""

    # --- Autonomy Level ---
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Autonomy Configuration" -ForegroundColor White
    Write-Host ""
    Write-Host "  1) Full autonomy - act on everything, only ask for irreversible actions"
    Write-Host "  2) Balanced - act on routine tasks, ask for new/unfamiliar ones"
    Write-Host "  3) Conservative - always ask before taking action"
    Write-Host ""
    $autoInput = Read-Host "  Autonomy level [1/2/3] [1]"
    $script:AutonomyLevel = if ($autoInput) { $autoInput } else { "1" }

    $styleInput = Read-Host "  Communication style [concise/detailed/casual] [concise]"
    $script:CommStyle = if ($styleInput) { $styleInput } else { "concise" }

    $hoursInput = Read-Host "  Working hours [24/7 / business / custom] [24/7]"
    $script:WorkingHours = if ($hoursInput) { $hoursInput } else { "24/7" }
    Write-Host ""

    # --- Heartbeat Scheduler ---
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Heartbeat Scheduler" -ForegroundColor White
    Write-Host ""
    Write-Host "  The heartbeat wakes the agent at intervals to run"
    Write-Host "  background tasks (monitoring, scheduled posts, inbox checks)."
    Write-Host ""
    $hbInput = Read-Host "  Enable heartbeat? [Y/n]"
    if ($hbInput -match '^[nN]') {
        $script:EnableHeartbeat = "false"
    } else {
        $script:EnableHeartbeat = "true"
        $hbInt = Read-Host "  Heartbeat interval (minutes) [15]"
        $script:HeartbeatInterval = if ($hbInt) { $hbInt } else { "15" }
        Log "  Heartbeat: every $HeartbeatInterval minutes"
    }
    Write-Host ""

    # --- Multi-Channel Gateway ---
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Communication Channels" -ForegroundColor White
    Write-Host ""
    $script:ChannelConfigs = @()
    foreach ($ch in @("telegram", "discord", "whatsapp", "slack", "signal")) {
        $chInput = Read-Host "  Enable ${ch}? [Y/n]"
        if ($chInput -notmatch '^[nN]') {
            $script:ChannelConfigs += $ch
        }
    }
    Write-Host ""
    if ($ChannelConfigs.Count -gt 0) {
        Log "  Channels: $($ChannelConfigs -join ', ')"
    } else {
        Log "  Channels: none (configure later)"
    }

    $notifyInput = Read-Host "  Primary notification channel [telegram]"
    $script:NotifyChannel = if ($notifyInput) { $notifyInput } else { "telegram" }
    Write-Host ""
}

# ============================================================================
# [1/7] Install knowledge
# ============================================================================
function Install-Knowledge {
    Log "=== [1/10] Installing Knowledge Base ==="
    $files = Get-ChildItem -Path $KnowledgeDir -Filter "*.md"

    if ($InstallMode -eq "local") {
        $dest = Join-Path $OpenClawHome "memory\content-engine"
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        foreach ($f in $files) {
            Copy-Item $f.FullName -Destination (Join-Path $dest $f.Name) -Force
        }
    } else {
        docker exec $ContainerName bash -c "mkdir -p /home/node/.openclaw/memory/content-engine"
        foreach ($f in $files) {
            docker cp $f.FullName "${ContainerName}:/home/node/.openclaw/memory/content-engine/$($f.Name)"
        }
        docker exec $ContainerName bash -c "chown -R node:node /home/node/.openclaw/memory" 2>$null
    }
    Log "  $($files.Count) knowledge files installed"
}

# ============================================================================
# [2/7] Install skill
# ============================================================================
function Install-Skill {
    Log "=== [2/10] Installing Skill ==="
    $skillFile = Join-Path $SkillDir "SKILL.md"

    if ($InstallMode -eq "local") {
        $dest = Join-Path $OpenClawHome "skills\content-engine"
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item $skillFile -Destination (Join-Path $dest "SKILL.md") -Force
        $scriptsDir = Join-Path $SkillDir "scripts"
        if (Test-Path $scriptsDir) {
            Copy-Item $scriptsDir -Destination $dest -Recurse -Force
        }
    } else {
        docker exec $ContainerName bash -c "mkdir -p /home/node/.openclaw/skills/content-engine"
        docker cp $skillFile "${ContainerName}:/home/node/.openclaw/skills/content-engine/SKILL.md"
        docker exec $ContainerName bash -c "chown -R node:node /home/node/.openclaw/skills/content-engine" 2>$null
    }
    Log "  content-engine skill installed"
}

# ============================================================================
# [2.5/7] Set up the default agent with browser + content identity
# ============================================================================
function Create-Agent {
    Log "=== [2.5/10] Setting Up Agent: $AgentEmoji $AgentName ==="

    $identitySrc = Join-Path $ScriptDir "IDENTITY.md"
    if (-not (Test-Path $identitySrc)) {
        Warn "  IDENTITY.md not found — skipping"
        return
    }

    # Generate IDENTITY.md with chosen name and emoji
    $identityContent = (Get-Content $identitySrc -Raw)
    $identityContent = $identityContent -replace '(?m)^- \*\*Name:\*\*.*', "- **Name:** $AgentName"
    $identityContent = $identityContent -replace '(?m)^- \*\*Emoji:\*\*.*', "- **Emoji:** $AgentEmoji"

    if ($InstallMode -eq "local") {
        # Find main agent workspace
        $ws = Join-Path $OpenClawHome "workspace"
        if ($OcBin) {
            try {
                $cfgWs = & $OcBin config get agents.defaults.workspace 2>$null
                if ($cfgWs -and $cfgWs -ne "undefined") { $ws = $cfgWs }
            } catch {}
        }
        New-Item -ItemType Directory -Path $ws -Force | Out-Null

        $dest = Join-Path $ws "IDENTITY.md"
        if (Test-Path $dest) {
            Copy-Item $dest -Destination "$dest.bak" -Force
            Log "  Backed up existing IDENTITY.md"
        }
        $identityContent | Set-Content -Path $dest -Encoding UTF8
        Log "  IDENTITY.md deployed to $ws/"

        # Set identity on the DEFAULT (main) agent — handles all messages
        if ($OcBin) {
            Log "  Registering identity: $AgentEmoji $AgentName..."
            try {
                & $OcBin agents set-identity --agent main --name $AgentName --emoji $AgentEmoji --identity-file $dest 2>$null
            } catch {
                try { & $OcBin agents set-identity --agent main --name $AgentName --emoji $AgentEmoji 2>$null } catch {}
            }
            Log "  $AgentEmoji $AgentName is the default agent (handles all messages)"
        }
    } else {
        $dockerWs = "/home/node/.openclaw/workspace"
        docker exec $ContainerName bash -c "mkdir -p $dockerWs" 2>$null

        $tmpFile = [System.IO.Path]::GetTempFileName()
        $identityContent | Set-Content -Path $tmpFile -Encoding UTF8

        $exists = docker exec $ContainerName bash -c "test -f $dockerWs/IDENTITY.md && echo yes" 2>$null
        if ($exists -eq "yes") {
            docker exec $ContainerName bash -c "cp $dockerWs/IDENTITY.md $dockerWs/IDENTITY.md.bak" 2>$null
        }
        docker cp $tmpFile "${ContainerName}:$dockerWs/IDENTITY.md"
        docker exec $ContainerName bash -c "chown node:node $dockerWs/IDENTITY.md" 2>$null
        Remove-Item $tmpFile -Force

        try {
            docker exec -u node $ContainerName openclaw agents set-identity --agent main --name $AgentName --emoji $AgentEmoji --identity-file "$dockerWs/IDENTITY.md" 2>$null
        } catch {}
        Log "  $AgentEmoji $AgentName is the default agent"
    }
}

# ============================================================================
# [2.7/10] Deploy SOUL.md
# ============================================================================
function Deploy-Soul {
    Log "=== [2.7/10] Deploying SOUL.md (Agent Personality & Goals) ==="

    $soulSrc = Join-Path $ScriptDir "SOUL.md"
    if (-not (Test-Path $soulSrc)) {
        Warn "  SOUL.md template not found - skipping"
        return
    }

    $soulContent = (Get-Content $soulSrc -Raw)
    $soulContent = $soulContent -replace '\[Your name\]', $(if ($OwnerName) { $OwnerName } else { "Not set" })
    $soulContent = $soulContent -replace '\[concise/detailed/casual/formal\]', $CommStyle
    $soulContent = $soulContent -replace '\[24/7 / business hours only / custom schedule\]', $WorkingHours
    $soulContent = $soulContent -replace '\[Telegram / Discord / Slack / all\]', $NotifyChannel

    $autonomyText = "Act autonomously on all routine tasks. Only ask for irreversible or high-risk actions."
    if ($AutonomyLevel -eq "2") { $autonomyText = "Act on routine/familiar tasks. Ask before attempting new or unfamiliar operations." }
    if ($AutonomyLevel -eq "3") { $autonomyText = "Always ask before taking any action. Provide recommendations but wait for approval." }
    $soulContent = $soulContent -replace '24/7 autonomous with human oversight for critical decisions', $autonomyText

    if ($InstallMode -eq "local") {
        $ws = Join-Path $OpenClawHome "workspace"
        New-Item -ItemType Directory -Path $ws -Force | Out-Null
        $dest = Join-Path $ws "SOUL.md"
        if (Test-Path $dest) {
            Copy-Item $dest -Destination "$dest.bak" -Force
            Log "  Backed up existing SOUL.md"
        }
        $soulContent | Set-Content -Path $dest -Encoding UTF8
        Log "  SOUL.md deployed to $ws/"
    } else {
        $dockerWs = "/home/node/.openclaw/workspace"
        docker exec $ContainerName bash -c "mkdir -p $dockerWs" 2>$null
        $tmpFile = [System.IO.Path]::GetTempFileName()
        $soulContent | Set-Content -Path $tmpFile -Encoding UTF8
        docker cp $tmpFile "${ContainerName}:$dockerWs/SOUL.md"
        docker exec $ContainerName bash -c "chown node:node $dockerWs/SOUL.md" 2>$null
        Remove-Item $tmpFile -Force
        Log "  SOUL.md deployed to container workspace"
    }
}

# ============================================================================
# [3/10] Configure OpenClaw
# ============================================================================
function Configure-OpenClaw {
    Log "=== [3/10] Configuring OpenClaw for Full Autonomy ==="

    if ($InstallMode -eq "local" -and -not $OcBin) {
        Warn "  openclaw CLI not found — writing config via JSON"
        Configure-ViaJson
        return
    }

    $settings = @(
        # Plugins
        @("plugins.entries.lobster.enabled", "true", "lobster (browser)"),
        @("plugins.entries.llm-task.enabled", "true", "llm-task (background)"),
        @("plugins.entries.open-prose.enabled", "true", "open-prose (text)"),
        @("plugins.entries.voice-call.enabled", "true", "voice-call (audio)"),
        # Browser
        # Browser — Playwright CLI as default engine
        @("browser.defaultProfile", "openclaw", "browser default profile"),
        @("browser.engine", "playwright", "browser engine = playwright"),
        @("browser.driver", "playwright", "browser driver = playwright"),
        @("browser.type", "chromium", "browser type = chromium"),
        @("browser.headless", "true", "headless mode"),
        @("browser.launchArgs", '["--no-sandbox","--disable-setuid-sandbox","--disable-dev-shm-usage"]', "browser launch args"),
        @("browser.navigationTimeout", "60000", "navigation timeout 60s"),
        @("browser.actionTimeout", "30000", "action timeout 30s"),
        # Tools — ALL permissions granted for ALL channels
        @("tools.allow", '["*"]', "allow ALL tools"),
        @("tools.elevated.enabled", "true", "elevated tools"),
        @("tools.elevated.allowFrom.telegram", '["*"]', "elevated from telegram"),
        @("tools.elevated.allowFrom.discord", '["*"]', "elevated from discord"),
        @("tools.elevated.allowFrom.whatsapp", '["*"]', "elevated from whatsapp"),
        @("tools.elevated.allowFrom.slack", '["*"]', "elevated from slack"),
        @("tools.elevated.allowFrom.signal", '["*"]', "elevated from signal"),
        @("tools.elevated.allowFrom.web", '["*"]', "elevated from web"),
        @("tools.elevated.allowFrom.api", '["*"]', "elevated from api"),
        # Browser — full access
        @("tools.browser.enabled", "true", "browser enabled"),
        @("tools.browser.allowNavigation", "true", "browser navigation"),
        @("tools.browser.allowDownloads", "true", "browser downloads"),
        @("tools.browser.allowUploads", "true", "browser uploads"),
        @("tools.browser.allowScreenshots", "true", "browser screenshots"),
        # Exec — full access
        @("tools.exec.enabled", "true", "exec enabled"),
        @("tools.exec.timeoutSec", "1800", "exec timeout 30min"),
        @("tools.exec.notifyOnExit", "true", "exec notify"),
        @("tools.exec.allowAll", "true", "exec allow all"),
        # Agent defaults
        @("agents.defaults.sandbox.mode", "off", "sandbox off"),
        @("agents.defaults.maxConcurrent", "4", "max agents"),
        @("agents.defaults.subagents.maxConcurrent", "8", "max subagents"),
        @("agents.defaults.compaction.mode", "safeguard", "compaction"),
        # Commands
        @("commands.native", "auto", "native commands"),
        @("commands.nativeSkills", "auto", "native skills"),
        # Skills
        @("skills.install.nodeManager", "npm", "node manager"),
        # Messages
        @("messages.ackReactionScope", "group-mentions", "ack reactions"),
        # Session persistence
        @("browser.persistSessions", "true", "session persistence"),
        @("browser.cookieStorage", "file", "cookie storage"),
        @("browser.saveCookiesOnExit", "true", "save cookies on exit"),
        @("browser.loadCookiesOnStart", "true", "load cookies on start"),
        @("sessions.autoSave", "true", "auto-save sessions"),
        @("sessions.maxAge", "30d", "session max age"),
        # Autonomy — ALL permissions granted
        @("tools.filesystem.enabled", "true", "filesystem access"),
        @("tools.filesystem.allowWrite", "true", "filesystem write"),
        @("tools.filesystem.allowDelete", "true", "filesystem delete"),
        @("tools.filesystem.allowCreate", "true", "filesystem create"),
        @("tools.clipboard.enabled", "true", "clipboard access"),
        @("tools.clipboard.allowRead", "true", "clipboard read"),
        @("tools.clipboard.allowWrite", "true", "clipboard write"),
        @("tools.process.enabled", "true", "process management"),
        @("tools.process.allowKill", "true", "process kill"),
        @("tools.process.allowSpawn", "true", "process spawn"),
        @("tools.network.enabled", "true", "network access"),
        @("tools.network.allowAll", "true", "network unrestricted"),
        @("tools.credentials.enabled", "true", "credentials enabled"),
        @("tools.credentials.autoSave", "true", "credential auto-save"),
        @("tools.credentials.allowRead", "true", "credential read"),
        @("tools.credentials.allowWrite", "true", "credential write"),
        @("memory.longTerm.enabled", "true", "long-term memory"),
        @("memory.longTerm.autoIndex", "true", "memory auto-index"),
        @("agents.defaults.canSpawn", "true", "agent spawning"),
        @("agents.defaults.canDelegate", "true", "agent delegation"),
        # Global permissions override
        @("permissions.mode", "unrestricted", "unrestricted permissions"),
        @("permissions.autoApprove", "true", "auto-approve all"),
        @("permissions.requireConfirmation", "false", "no confirmation needed")
    )

    foreach ($s in $settings) {
        Log "  $($s[2])..."
        Oc-Config -Args @("set", $s[0], $s[1])
    }

    if ($InstallMode -eq "local") {
        $ws = (Join-Path $OpenClawHome "workspace").Replace("\", "/")
        Log "  workspace..."
        Oc-Config -Args @("set", "agents.defaults.workspace", $ws)
    }

    # Heartbeat scheduler
    if ($EnableHeartbeat -eq "true") {
        Log "  Configuring heartbeat scheduler..."
        Oc-Config -Args @("set", "heartbeat.enabled", "true")
        Oc-Config -Args @("set", "heartbeat.intervalMinutes", $HeartbeatInterval)
        Oc-Config -Args @("set", "heartbeat.tasks.checkInbox", "true")
        Oc-Config -Args @("set", "heartbeat.tasks.monitorApps", "true")
        Oc-Config -Args @("set", "heartbeat.tasks.scheduledContent", "true")
        Oc-Config -Args @("set", "heartbeat.tasks.healthCheck", "true")
    }

    # Multi-channel gateway
    foreach ($ch in $ChannelConfigs) {
        Log "  Enabling channel: $ch..."
        Oc-Config -Args @("set", "channels.$ch.enabled", "true")
        Oc-Config -Args @("set", "tools.elevated.allowFrom.$ch", '["*"]')
    }

    # Notification preferences
    if ($NotifyChannel) {
        Oc-Config -Args @("set", "notifications.defaultChannel", $NotifyChannel)
        Oc-Config -Args @("set", "notifications.onTaskComplete", "true")
        Oc-Config -Args @("set", "notifications.onError", "true")
    }

    # Install lobster plugin (provides the browser tool)
    Log "  Installing lobster plugin..."
    Oc-Cmd -Args @("plugins", "install", "lobster")

    # Install Playwright CLI + browsers (default navigation engine)
    Log "  Installing Playwright CLI and Chromium browser..."
    try { npx playwright install chromium 2>$null } catch {}
    try { npx playwright install-deps chromium 2>$null } catch {}
    # Global install as fallback
    try {
        $npmList = npm list -g playwright 2>$null
        if (-not $npmList -or $npmList -notmatch "playwright") {
            npm install -g playwright 2>$null
        }
    } catch {}
    Oc-Cmd -Args @("browser", "setup")
    Oc-Cmd -Args @("browser", "install")

    # Create Playwright browser profile
    Log "  Creating Playwright browser profile..."
    Oc-Cmd -Args @("browser", "create-profile", "--name", "openclaw", "--driver", "playwright", "--color", "#FF4500")

    Log "  All settings applied"
}

function Configure-ViaJson {
    $configFile = Join-Path $OpenClawHome "openclaw.json"
    $ws = (Join-Path $OpenClawHome "workspace").Replace("\", "/")

    # Use Node.js
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Log "  Writing config via Node.js..."
        $nodeScript = @"
var fs = require('fs');
var p = process.argv[1], ws = process.argv[2];
var cfg = {};
try { cfg = JSON.parse(fs.readFileSync(p, 'utf8')); } catch(e) {}
if (!cfg.plugins) cfg.plugins = {};
if (!cfg.plugins.entries) cfg.plugins.entries = {};
cfg.plugins.entries.lobster = { enabled: true };
cfg.plugins.entries['llm-task'] = { enabled: true };
cfg.plugins.entries['open-prose'] = { enabled: true };
cfg.plugins.entries['voice-call'] = { enabled: true };
if (!cfg.tools) cfg.tools = {};
cfg.tools.allow = ['*'];
if (!cfg.tools.elevated) cfg.tools.elevated = {};
cfg.tools.elevated.enabled = true;
if (!cfg.tools.elevated.allowFrom) cfg.tools.elevated.allowFrom = {};
['telegram','discord','whatsapp','slack','signal','web','api'].forEach(function(ch) { cfg.tools.elevated.allowFrom[ch] = ['*']; });
cfg.tools.browser = { enabled: true, allowNavigation: true, allowDownloads: true, allowUploads: true, allowScreenshots: true };
if (!cfg.tools.exec) cfg.tools.exec = {};
cfg.tools.exec = { enabled: true, timeoutSec: 1800, notifyOnExit: true, allowAll: true };
cfg.tools.filesystem = { enabled: true, allowWrite: true, allowDelete: true, allowCreate: true };
cfg.tools.clipboard = { enabled: true, allowRead: true, allowWrite: true };
cfg.tools.process = { enabled: true, allowKill: true, allowSpawn: true };
cfg.tools.network = { enabled: true, allowAll: true };
cfg.tools.credentials = { enabled: true, autoSave: true, allowRead: true, allowWrite: true };
cfg.permissions = { mode: 'unrestricted', autoApprove: true, requireConfirmation: false };
if (!cfg.messages) cfg.messages = {};
cfg.messages.ackReactionScope = 'group-mentions';
if (!cfg.agents) cfg.agents = {};
if (!cfg.agents.defaults) cfg.agents.defaults = {};
cfg.agents.defaults.sandbox = { mode: 'off' };
cfg.agents.defaults.maxConcurrent = 4;
cfg.agents.defaults.subagents = { maxConcurrent: 8 };
cfg.agents.defaults.compaction = { mode: 'safeguard' };
cfg.agents.defaults.workspace = ws;
cfg.agents.defaults.canSpawn = true;
cfg.agents.defaults.canDelegate = true;
if (!cfg.commands) cfg.commands = {};
cfg.commands.native = 'auto';
cfg.commands.nativeSkills = 'auto';
if (!cfg.skills) cfg.skills = {};
cfg.skills.install = { nodeManager: 'npm' };
if (!cfg.browser) cfg.browser = {};
cfg.browser.defaultProfile = 'openclaw';
cfg.browser.engine = 'playwright';
cfg.browser.driver = 'playwright';
cfg.browser.type = 'chromium';
cfg.browser.headless = true;
cfg.browser.launchArgs = ['--no-sandbox','--disable-setuid-sandbox','--disable-dev-shm-usage'];
cfg.browser.navigationTimeout = 60000;
cfg.browser.actionTimeout = 30000;
cfg.browser.persistSessions = true;
cfg.browser.cookieStorage = 'file';
cfg.browser.saveCookiesOnExit = true;
cfg.browser.loadCookiesOnStart = true;
if (!cfg.sessions) cfg.sessions = {};
cfg.sessions.autoSave = true;
cfg.sessions.maxAge = '30d';
if (!cfg.memory) cfg.memory = {};
cfg.memory.longTerm = { enabled: true, autoIndex: true };
fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
"@
        node -e $nodeScript $configFile $ws
        Log "  Config written"
        return
    }

    # Use Python
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if ($py) {
        Log "  Writing config via Python..."
        $pyScript = @"
import json, sys, os
path, ws = sys.argv[1], sys.argv[2]
cfg = {}
if os.path.exists(path):
    try:
        with open(path) as f: cfg = json.load(f)
    except: pass
cfg.setdefault("plugins", {}).setdefault("entries", {})
cfg["plugins"]["entries"]["lobster"] = {"enabled": True}
cfg["plugins"]["entries"]["llm-task"] = {"enabled": True}
cfg["plugins"]["entries"]["open-prose"] = {"enabled": True}
cfg["plugins"]["entries"]["voice-call"] = {"enabled": True}
cfg.setdefault("tools", {})
cfg["tools"]["allow"] = ["*"]
cfg["tools"].setdefault("elevated", {})["enabled"] = True
cfg["tools"].setdefault("elevated", {}).setdefault("allowFrom", {})
for ch in ["telegram","discord","whatsapp","slack","signal","web","api"]:
    cfg["tools"]["elevated"]["allowFrom"][ch] = ["*"]
cfg["tools"]["browser"] = {"enabled": True, "allowNavigation": True, "allowDownloads": True, "allowUploads": True, "allowScreenshots": True}
cfg["tools"]["exec"] = {"enabled": True, "timeoutSec": 1800, "notifyOnExit": True, "allowAll": True}
cfg["tools"]["filesystem"] = {"enabled": True, "allowWrite": True, "allowDelete": True, "allowCreate": True}
cfg["tools"]["clipboard"] = {"enabled": True, "allowRead": True, "allowWrite": True}
cfg["tools"]["process"] = {"enabled": True, "allowKill": True, "allowSpawn": True}
cfg["tools"]["network"] = {"enabled": True, "allowAll": True}
cfg["tools"]["credentials"] = {"enabled": True, "autoSave": True, "allowRead": True, "allowWrite": True}
cfg["permissions"] = {"mode": "unrestricted", "autoApprove": True, "requireConfirmation": False}
cfg.setdefault("messages", {})
cfg["messages"]["ackReactionScope"] = "group-mentions"
cfg.setdefault("agents", {}).setdefault("defaults", {})
cfg["agents"]["defaults"]["sandbox"] = {"mode": "off"}
cfg["agents"]["defaults"]["maxConcurrent"] = 4
cfg["agents"]["defaults"]["subagents"] = {"maxConcurrent": 8}
cfg["agents"]["defaults"]["compaction"] = {"mode": "safeguard"}
cfg["agents"]["defaults"]["workspace"] = ws
cfg["agents"]["defaults"]["canSpawn"] = True
cfg["agents"]["defaults"]["canDelegate"] = True
cfg.setdefault("commands", {})
cfg["commands"]["native"] = "auto"
cfg["commands"]["nativeSkills"] = "auto"
cfg.setdefault("skills", {})
cfg["skills"]["install"] = {"nodeManager": "npm"}
cfg.setdefault("browser", {})
cfg["browser"]["defaultProfile"] = "openclaw"
cfg["browser"]["engine"] = "playwright"
cfg["browser"]["driver"] = "playwright"
cfg["browser"]["type"] = "chromium"
cfg["browser"]["headless"] = True
cfg["browser"]["launchArgs"] = ["--no-sandbox","--disable-setuid-sandbox","--disable-dev-shm-usage"]
cfg["browser"]["navigationTimeout"] = 60000
cfg["browser"]["actionTimeout"] = 30000
cfg["browser"]["persistSessions"] = True
cfg["browser"]["cookieStorage"] = "file"
cfg["browser"]["saveCookiesOnExit"] = True
cfg["browser"]["loadCookiesOnStart"] = True
cfg.setdefault("sessions", {})
cfg["sessions"]["autoSave"] = True
cfg["sessions"]["maxAge"] = "30d"
cfg.setdefault("memory", {})
cfg["memory"]["longTerm"] = {"enabled": True, "autoIndex": True}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
"@
        & $py.Source -c $pyScript $configFile $ws
        Log "  Config written"
        return
    }

    Err "  No node or python found. Config NOT written."
    Err "  Install Node.js or openclaw CLI and re-run."
}

# ============================================================================
# [4/7] Credentials
# ============================================================================
function Deploy-Credentials {
    Log "=== [5/10] Setting Up Credentials ==="

    if ($InstallMode -eq "local") {
        New-Item -ItemType Directory -Path (Join-Path $OpenClawHome "sessions") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $OpenClawHome "workspace") -Force | Out-Null
        $credsDest = Join-Path $OpenClawHome "credentials.json"
        if (Test-Path $credsDest) {
            Log "  credentials.json already exists — keeping it"
        } else {
            Copy-Item $CredsTemplate -Destination $credsDest
            Warn "  credentials.json created at:"
            Warn "  $credsDest"
            Warn "  >>> EDIT THIS FILE and add your platform logins <<<"
        }
    } else {
        docker exec $ContainerName bash -c "mkdir -p /home/node/.openclaw/sessions /home/node/.openclaw/workspace"
        $exists = docker exec $ContainerName bash -c "test -f /home/node/.openclaw/credentials.json && echo yes" 2>$null
        if ($exists -eq "yes") {
            Log "  credentials.json already exists — keeping it"
        } else {
            docker cp $CredsTemplate "${ContainerName}:/home/node/.openclaw/credentials.json"
            docker exec $ContainerName bash -c "chown node:node /home/node/.openclaw/credentials.json && chmod 600 /home/node/.openclaw/credentials.json"
            Warn "  credentials.json deployed. Edit with:"
            Warn "  docker exec -it $ContainerName nano /home/node/.openclaw/credentials.json"
        }
    }
}

# ============================================================================
# [5/7] Reindex memory
# ============================================================================
function Reindex-Memory {
    Log "=== [6/10] Indexing Memory ==="
    if ($OcBin -or $InstallMode -eq "docker") {
        Oc-Cmd -Args @("memory", "index", "--force")
        Log "  Memory indexed"
    } else {
        Warn "  Skipped — run manually: openclaw memory index --force"
    }
}

# ============================================================================
# [6/7] Full restart of OpenClaw gateway to load new config
# ============================================================================
function Restart-Gateway {
    Log "=== [7/10] Full OpenClaw Restart ==="

    if ($InstallMode -eq "docker") {
        Log "  Stopping container $ContainerName..."
        try { docker stop $ContainerName 2>$null } catch {}
        Start-Sleep -Seconds 2
        Log "  Starting container $ContainerName..."
        try { docker start $ContainerName 2>$null } catch { Err "  Failed to start container" ; return }
        Start-Sleep -Seconds 10
        Log "  Container restarted"
        return
    }

    if (-not $OcBin) {
        Warn "  openclaw CLI not found — restart manually after install"
        return
    }

    # Step 1: Stop all nodes first, then kill gateway
    Log "  Stopping all OpenClaw nodes and gateway..."

    # Stop all node hosts first (they depend on gateway)
    try { & $OcBin node stop --all 2>$null } catch {}
    try { & $OcBin node stop 2>$null } catch {}

    # Stop individual nodes
    try {
        $allNodes = & $OcBin nodes list 2>$null | Out-String
        $nodeIds = [regex]::Matches($allNodes, '[a-f0-9-]{8,}') | ForEach-Object { $_.Value }
        foreach ($nid in $nodeIds) {
            Log "  Stopping node: $nid"
            try { & $OcBin node stop $nid 2>$null } catch {}
        }
    } catch {}

    # Kill any lingering node host processes
    try {
        Get-WmiObject Win32_Process -Filter "CommandLine like '%openclaw%node%run%'" -ErrorAction SilentlyContinue |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch {}

    Start-Sleep -Seconds 1

    # Now stop the gateway
    try { & $OcBin gateway stop 2>$null } catch {}
    Start-Sleep -Seconds 1

    # Kill by port 18789
    $gwPort = 18789
    try {
        $cfgPort = & $OcBin config get gateway.port 2>$null
        if ($cfgPort -match '^\d+$') { $gwPort = [int]$cfgPort }
    } catch {}

    $portProcs = netstat -ano 2>$null | Select-String ":$gwPort\s.*LISTEN"
    foreach ($line in $portProcs) {
        if ($line -match '\s(\d+)\s*$') {
            $pid = $Matches[1]
            if ($pid -and $pid -ne "0") {
                Log "  Killing PID $pid (port $gwPort)..."
                try { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    # Kill any node process running openclaw gateway
    try {
        Get-WmiObject Win32_Process -Filter "CommandLine like '%openclaw%gateway%'" -ErrorAction SilentlyContinue |
            ForEach-Object { Log "  Killing PID $($_.ProcessId)..."; Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch {}

    Start-Sleep -Seconds 3
    Log "  All OpenClaw processes killed"

    # Step 2: Start gateway fresh
    Log "  Starting OpenClaw gateway..."
    $proc = Start-Process -FilePath $OcBin -ArgumentList "gateway","--force" -WindowStyle Hidden -PassThru

    # Step 3: Wait for gateway
    Log "  Waiting for gateway to come online..."
    $gwUp = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 2
        try {
            $statusOut = & $OcBin gateway status 2>$null | Out-String
            if ($statusOut -match "RPC probe: ok") {
                $gwUp = $true
                break
            }
        } catch {}
    }

    if ($gwUp) {
        Log "  OpenClaw gateway is running (new config loaded)"
    } else {
        Err "  Gateway did not start within 30 seconds"
        Err "  Start manually: openclaw gateway --force"
    }

    # Step 4: Restart ALL node hosts
    Log "  Restarting all node hosts..."

    $gwHost = "127.0.0.1"

    # Install/reinstall local node host
    try { & $OcBin node install --host $gwHost --port $gwPort --force 2>$null } catch { Warn "  node install failed" }

    # Restart all nodes
    try { & $OcBin node restart --all 2>$null } catch {}
    try { & $OcBin node restart 2>$null } catch {
        Log "  Starting local node host in background..."
        Start-Process -FilePath $OcBin -ArgumentList "node","run","--host",$gwHost,"--port",$gwPort -WindowStyle Hidden
    }

    # Step 5: Approve all node pairing requests
    Log "  Approving all node pairing requests..."
    Start-Sleep -Seconds 5

    try { & $OcBin devices approve --all 2>$null } catch {}
    try { & $OcBin nodes approve --all 2>$null } catch {}

    try {
        $devicesOut = & $OcBin devices list 2>$null | Out-String
        Log "  Devices: $devicesOut"
        $ids = [regex]::Matches($devicesOut, '[a-f0-9-]{8,}') | ForEach-Object { $_.Value }
        foreach ($rid in $ids) {
            Log "  Approving device: $rid"
            try { & $OcBin devices approve $rid 2>$null } catch {}
        }
    } catch {}

    # Step 6: Wait for all nodes to reconnect
    Log "  Waiting for all node hosts to reconnect..."
    $nodeUp = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 3
        try {
            $nodesOut = & $OcBin nodes status 2>$null | Out-String
            if ($nodesOut -match "Connected: [1-9]") {
                $nodeUp = $true
                if ($nodesOut -match "Connected: (\d+)") {
                    Log "  Nodes connected: $($Matches[1])"
                }
                break
            }
        } catch {}
        # Keep approving new pairing requests
        try {
            $newDev = & $OcBin devices list 2>$null | Out-String
            $newIds = [regex]::Matches($newDev, '[a-f0-9-]{8,}') | ForEach-Object { $_.Value }
            foreach ($rid in $newIds) { try { & $OcBin devices approve $rid 2>$null } catch {} }
        } catch {}
        try { & $OcBin devices approve --all 2>$null } catch {}
        try { & $OcBin nodes approve --all 2>$null } catch {}
    }

    if ($nodeUp) {
        Log "  All node hosts: CONNECTED (agent has full tool access)"
    } else {
        Warn "  Some node hosts may not have reconnected"
        Warn "  Manual fix:"
        Warn "    1. openclaw nodes status            (check connected nodes)"
        Warn "    2. openclaw devices list             (find pending requests)"
        Warn "    3. openclaw devices approve --all    (approve all)"
        Warn "    4. openclaw node restart --all       (restart all nodes)"
    }
}

# ============================================================================
# [7/7] Verify
# ============================================================================
function Verify-Install {
    Log "=== [8/10] Verifying Installation ==="

    if ($InstallMode -eq "local") {
        $kDir = Join-Path $OpenClawHome "memory\content-engine"
        if (Test-Path $kDir) {
            $kCount = (Get-ChildItem -Path $kDir -Filter "*.md").Count
            Log "  Knowledge: $kCount files"
        } else { Err "  Knowledge: NOT FOUND" }

        $skillPath = Join-Path $OpenClawHome "skills\content-engine\SKILL.md"
        if (Test-Path $skillPath) { Log "  Skill: INSTALLED" } else { Err "  Skill: NOT FOUND" }

        $credsPath = Join-Path $OpenClawHome "credentials.json"
        if (Test-Path $credsPath) { Log "  Credentials: PRESENT" } else { Warn "  Credentials: NOT FOUND" }

        if ($OcBin) {
            try {
                $browserEngine = & $OcBin config get browser.engine 2>$null
                if ($browserEngine -eq "playwright") {
                    Log "  Browser engine: PLAYWRIGHT"
                } else {
                    Warn "  Browser engine: $browserEngine (expected: playwright)"
                    Warn "  Fix: openclaw config set browser.engine playwright"
                }
            } catch {}

            try {
                $skillOut = & $OcBin skills list 2>$null | Out-String
                if ($skillOut -match "content-engine") {
                    if ($skillOut -match "ready.*content-engine|content-engine.*ready") {
                        Log "  Skill status: READY"
                    } else { Warn "  Skill visible (restart gateway for ready)" }
                } else { Warn "  Skill not visible yet (restart gateway)" }
            } catch {}
        }

        if (Test-Path (Join-Path $OpenClawHome "workspace")) { Log "  Workspace: OK" }
        if (Test-Path (Join-Path $OpenClawHome "sessions")) { Log "  Sessions: OK" }
    } else {
        $c = docker exec $ContainerName bash -c "ls -1 /home/node/.openclaw/memory/content-engine/*.md 2>/dev/null | wc -l" 2>$null
        if ([int]$c -gt 0) { Log "  Knowledge: $c files" } else { Err "  Knowledge: NOT FOUND" }
    }
}

# ============================================================================
# Summary
# ============================================================================
function Print-Summary {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  OpenClaw Fully Autonomous Agent — Installation Complete" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Mode:     $($InstallMode.ToUpper()) on Windows" -ForegroundColor Green
    Write-Host "  Agent:    $AgentEmoji $AgentName" -ForegroundColor Green
    if ($OwnerName) { Write-Host "  Owner:    $OwnerName" -ForegroundColor Green }
    if ($ChannelConfigs.Count -gt 0) { Write-Host "  Channels: $($ChannelConfigs -join ', ')" -ForegroundColor Green }
    if ($EnableHeartbeat -eq "true") { Write-Host "  Heartbeat: every $HeartbeatInterval minutes" -ForegroundColor Green }
    Write-Host ""
    Write-Host "  Installed:" -ForegroundColor Green
    Write-Host "    - Agent identity (IDENTITY.md + SOUL.md)"
    Write-Host "    - 16 knowledge files (content + autonomous ops + system control)"
    Write-Host "    - content-engine skill"
    Write-Host "    - credentials.json template (30+ platform slots)"
    Write-Host ""
    Write-Host "  Browser: Playwright CLI (chromium, headless)" -ForegroundColor Green
    Write-Host "  Permissions: ALL GRANTED (unrestricted)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Capabilities:" -ForegroundColor Green
    Write-Host "    - Browse any website, log in, interact"
    Write-Host "    - Create accounts on new platforms"
    Write-Host "    - Generate 2FA codes automatically"
    Write-Host "    - Control file system, apps, processes"
    Write-Host "    - Run scheduled background tasks"
    Write-Host "    - Multi-channel communication"
    Write-Host "    - Content creation and social publishing"
    Write-Host "    - Session persistence (cookies saved)"
    Write-Host ""
    Write-Host "  Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    1. Edit credentials.json with your platform logins"
    if ($InstallMode -eq "local") {
        Write-Host "       $OpenClawHome\credentials.json" -ForegroundColor Yellow
    } else {
        Write-Host "       docker exec -it $ContainerName nano /home/node/.openclaw/credentials.json" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "    2. Customize SOUL.md with your goals and preferences"
    if ($InstallMode -eq "local") {
        Write-Host "       $OpenClawHome\workspace\SOUL.md" -ForegroundColor Yellow
    } else {
        Write-Host "       docker exec -it $ContainerName nano /home/node/.openclaw/workspace/SOUL.md" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "    3. Configure channel tokens"
    Write-Host "       openclaw config set channels.telegram.token YOUR_TOKEN" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '    4. Test: "Open the browser and go to google.com"'
    Write-Host '       "Create a new GitHub account"'
    Write-Host '       "Take a screenshot of the desktop"'
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# Main
# ============================================================================
function Main {
    Log "OS: Windows PowerShell"

    # Validate files exist
    if (-not (Test-Path $KnowledgeDir)) {
        Err "Knowledge directory not found: $KnowledgeDir"
        Err "Run from the openclaw-content-engine directory."
        exit 1
    }
    $mdCount = (Get-ChildItem -Path $KnowledgeDir -Filter "*.md" -ErrorAction SilentlyContinue).Count
    if ($mdCount -eq 0) { Err "No .md files in $KnowledgeDir"; exit 1 }

    if (-not (Test-Path (Join-Path $SkillDir "SKILL.md"))) {
        Err "SKILL.md not found in $SkillDir"; exit 1
    }
    if (-not (Test-Path $CredsTemplate)) {
        Err "credentials-template.json not found"; exit 1
    }

    Detect-Installations
    Install-Knowledge
    Install-Skill
    Create-Agent
    Deploy-Soul
    Configure-OpenClaw
    Deploy-Credentials
    Reindex-Memory
    Restart-Gateway
    Verify-Install
    Print-Summary
}

Main
