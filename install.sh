#!/usr/bin/env bash
# ============================================================================
# Content Engine — Cross-Platform Installer (bash)
# Works on: Linux, macOS, Windows (Git Bash / WSL / MSYS2 / Cygwin)
# Configures ALL OpenClaw plugins, tools, and settings for full autonomy
# ============================================================================
set -euo pipefail

# --- Colors (safe for all terminals) ---
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

log()  { echo -e "${GREEN}[Content-Engine]${NC} $*"; }
warn() { echo -e "${YELLOW}[Content-Engine]${NC} $*"; }
err()  { echo -e "${RED}[Content-Engine]${NC} $*" >&2; }

# --- Detect OS ---
detect_os() {
    case "$(uname -s 2>/dev/null || echo Unknown)" in
        Linux*)   OS_TYPE="linux" ;;
        Darwin*)  OS_TYPE="macos" ;;
        CYGWIN*|MINGW*|MSYS*) OS_TYPE="windows" ;;
        *)        OS_TYPE="unknown" ;;
    esac
    # WSL detection
    if [ "$OS_TYPE" = "linux" ] && grep -qi microsoft /proc/version 2>/dev/null; then
        OS_TYPE="wsl"
    fi
}

# --- Script directory (works across OS) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_DIR="${SCRIPT_DIR}/knowledge"
SKILL_DIR="${SCRIPT_DIR}/skills/content-engine"
CREDS_TEMPLATE="${SCRIPT_DIR}/credentials-template.json"

INSTALL_MODE=""
OPENCLAW_HOME=""
CONTAINER_NAME=""
OC_BIN=""
OS_TYPE=""
AGENT_NAME=""
AGENT_EMOJI=""

# ============================================================================
# Find openclaw binary (cross-platform)
# ============================================================================
find_openclaw_bin() {
    # 1. Direct PATH lookup
    if command -v openclaw >/dev/null 2>&1; then
        OC_BIN="openclaw"
        return 0
    fi

    # 2. npx cache (Windows npm installs via Git Bash / MSYS2)
    local npx_base=""
    if [ -n "${LOCALAPPDATA:-}" ]; then
        npx_base="$(echo "$LOCALAPPDATA" | sed 's|\\|/|g')/npm-cache/_npx"
    elif [ -d "$HOME/AppData/Local/npm-cache/_npx" ]; then
        npx_base="$HOME/AppData/Local/npm-cache/_npx"
    fi
    if [ -n "$npx_base" ] && [ -d "$npx_base" ]; then
        local found=""
        found=$(find "$npx_base" -maxdepth 4 -name "openclaw" -path "*/node_modules/.bin/*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then OC_BIN="$found"; return 0; fi
        found=$(find "$npx_base" -maxdepth 4 -name "openclaw.cmd" -path "*/node_modules/.bin/*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then OC_BIN="$found"; return 0; fi
    fi

    # 3. Global npm bin
    if command -v npm >/dev/null 2>&1; then
        local npm_prefix=""
        npm_prefix=$(npm prefix -g 2>/dev/null || true)
        if [ -n "$npm_prefix" ]; then
            for suffix in "bin/openclaw" "openclaw" "openclaw.cmd"; do
                if [ -f "$npm_prefix/$suffix" ]; then
                    OC_BIN="$npm_prefix/$suffix"
                    return 0
                fi
            done
        fi
    fi

    # 4. Common locations per OS
    local search_paths=""
    case "$OS_TYPE" in
        linux|wsl)
            search_paths="/usr/local/bin/openclaw /usr/bin/openclaw $HOME/.local/bin/openclaw $HOME/.npm-global/bin/openclaw" ;;
        macos)
            search_paths="/usr/local/bin/openclaw /opt/homebrew/bin/openclaw $HOME/.npm-global/bin/openclaw" ;;
        windows)
            search_paths="$HOME/AppData/Roaming/npm/openclaw $HOME/AppData/Roaming/npm/openclaw.cmd" ;;
    esac
    for p in $search_paths; do
        if [ -f "$p" ]; then OC_BIN="$p"; return 0; fi
    done

    return 1
}

# ============================================================================
# Detect OpenClaw installations
# ============================================================================
detect_installations() {
    echo ""
    log "Scanning for OpenClaw installations..."
    echo ""

    local found_local=false
    local found_docker=false
    local local_path=""
    local docker_containers=""

    # Build candidate paths based on OS
    local candidates="$HOME/.openclaw"

    case "$OS_TYPE" in
        linux|wsl)
            candidates="$candidates /home/node/.openclaw"
            ;;
        macos)
            candidates="$candidates $HOME/Library/Application Support/openclaw"
            ;;
        windows)
            if [ -n "${USERPROFILE:-}" ]; then
                local wp
                wp=$(echo "$USERPROFILE" | sed 's|\\|/|g')
                candidates="$candidates $wp/.openclaw"
            fi
            if [ -n "${APPDATA:-}" ]; then
                local ap
                ap=$(echo "$APPDATA" | sed 's|\\|/|g')
                candidates="$candidates $ap/openclaw"
            fi
            ;;
    esac

    # Check each candidate (skip duplicates)
    local checked=""
    for candidate in $candidates; do
        # Normalize path
        candidate=$(echo "$candidate" | sed 's|//|/|g')
        # Skip if already checked
        case "$checked" in *"|$candidate|"*) continue ;; esac
        checked="$checked|$candidate|"

        if [ -d "$candidate" ] 2>/dev/null; then
            local_path="$candidate"
            found_local=true
            break
        fi
    done

    # Find openclaw binary
    find_openclaw_bin && log "  Binary found: ${OC_BIN}" || warn "  openclaw binary not found in PATH"

    # Docker detection
    if command -v docker >/dev/null 2>&1; then
        docker_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i "claw" || true)
        if [ -n "$docker_containers" ]; then found_docker=true; fi
    fi

    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  OpenClaw Content Engine Installer${NC}"
    echo -e "${CYAN}  OS: ${OS_TYPE} | Shell: ${SHELL:-bash}${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${BOLD}Detected:${NC}"
    echo ""

    if $found_local; then
        echo -e "  ${GREEN}[LOCAL]${NC}   ${local_path}"
    fi
    if $found_docker; then
        echo -e "  ${GREEN}[DOCKER]${NC}  Containers:"
        echo "$docker_containers" | while read -r name; do
            echo -e "            - ${name}"
        done
    fi
    if ! $found_local && ! $found_docker; then
        echo -e "  ${YELLOW}No OpenClaw installation detected.${NC}"
        echo -e "  ${YELLOW}Install OpenClaw first: https://docs.openclaw.ai${NC}"
    fi

    echo ""
    echo -e "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    echo -e "  ${BOLD}Where do you want to install?${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Local install"
    if $found_local; then
        echo -e "     -> ${local_path}"
    else
        echo -e "     -> ~/.openclaw"
    fi
    echo ""
    echo -e "  ${BOLD}2)${NC} Docker container"
    if $found_docker; then
        echo -e "     -> $(echo "$docker_containers" | head -1)"
    else
        echo -e "     -> Specify container name"
    fi
    echo ""
    echo -e "  ${BOLD}3)${NC} Custom path"
    echo ""

    while true; do
        printf "  %bChoose [1/2/3]:%b " "$BOLD" "$NC"
        read -r choice
        case "$choice" in
            1)
                INSTALL_MODE="local"
                OPENCLAW_HOME="${local_path:-$HOME/.openclaw}"
                break ;;
            2)
                INSTALL_MODE="docker"
                if ! command -v docker >/dev/null 2>&1; then
                    err "Docker is not installed."; continue
                fi
                if $found_docker; then
                    CONTAINER_NAME=$(echo "$docker_containers" | head -1)
                    printf "  Container [%s]: " "$CONTAINER_NAME"
                    read -r cn
                    if [ -n "$cn" ]; then CONTAINER_NAME="$cn"; fi
                else
                    printf "  Container name: "
                    read -r CONTAINER_NAME
                    if [ -z "$CONTAINER_NAME" ]; then err "Required."; continue; fi
                fi
                if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                    err "'${CONTAINER_NAME}' is not running."
                    continue
                fi
                break ;;
            3)
                printf "  OpenClaw config path: "
                read -r custom_path
                if [ -z "$custom_path" ]; then err "Required."; continue; fi
                INSTALL_MODE="local"
                OPENCLAW_HOME="$custom_path"
                break ;;
            *) warn "Enter 1, 2, or 3." ;;
        esac
    done

    echo ""
    if [ "$INSTALL_MODE" = "local" ]; then
        log "Mode: LOCAL -> ${OPENCLAW_HOME}"
    else
        log "Mode: DOCKER -> ${CONTAINER_NAME}"
    fi
    echo ""

    # --- Agent name ---
    echo -e "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    echo -e "  ${BOLD}Agent Configuration${NC}"
    echo ""
    echo -e "  The installer will create a dedicated content engine agent."
    echo -e "  This agent will have browser control, content creation skills,"
    echo -e "  and its own identity."
    echo ""
    printf "  %bAgent name%b [ContentEngine]: " "$BOLD" "$NC"
    read -r agent_input
    AGENT_NAME="${agent_input:-ContentEngine}"

    printf "  %bAgent emoji%b [🎬]: " "$BOLD" "$NC"
    read -r emoji_input
    AGENT_EMOJI="${emoji_input:-🎬}"

    echo ""
    log "Agent: ${AGENT_EMOJI} ${AGENT_NAME}"
    echo ""
}

# ============================================================================
# Run openclaw commands
# ============================================================================
oc_config() {
    if [ "$INSTALL_MODE" = "local" ] && [ -n "$OC_BIN" ]; then
        "$OC_BIN" config "$@" 2>/dev/null || true
    elif [ "$INSTALL_MODE" = "docker" ]; then
        docker exec -u node "$CONTAINER_NAME" openclaw config "$@" 2>/dev/null || true
    fi
}

oc_cmd() {
    if [ "$INSTALL_MODE" = "local" ] && [ -n "$OC_BIN" ]; then
        "$OC_BIN" "$@" 2>/dev/null || true
    elif [ "$INSTALL_MODE" = "docker" ]; then
        docker exec -u node "$CONTAINER_NAME" openclaw "$@" 2>/dev/null || true
    fi
}

# ============================================================================
# [1/7] Install knowledge base
# ============================================================================
install_knowledge() {
    log "=== [1/7] Installing Knowledge Base ==="

    if [ "$INSTALL_MODE" = "local" ]; then
        mkdir -p "${OPENCLAW_HOME}/memory/content-engine"
        for f in "$KNOWLEDGE_DIR"/*.md; do
            [ -f "$f" ] || continue
            cp "$f" "${OPENCLAW_HOME}/memory/content-engine/$(basename "$f")"
        done
    else
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p /home/node/.openclaw/memory/content-engine"
        for f in "$KNOWLEDGE_DIR"/*.md; do
            [ -f "$f" ] || continue
            docker cp "$f" "${CONTAINER_NAME}:/home/node/.openclaw/memory/content-engine/$(basename "$f")"
        done
        docker exec "$CONTAINER_NAME" bash -c "chown -R node:node /home/node/.openclaw/memory" 2>/dev/null || true
    fi

    local count=0
    for f in "$KNOWLEDGE_DIR"/*.md; do [ -f "$f" ] && count=$((count + 1)); done
    log "  ${count} knowledge files installed"
}

# ============================================================================
# [2/7] Install skill
# ============================================================================
install_skill() {
    log "=== [2/7] Installing Skill ==="

    if [ "$INSTALL_MODE" = "local" ]; then
        mkdir -p "${OPENCLAW_HOME}/skills/content-engine"
        cp "$SKILL_DIR/SKILL.md" "${OPENCLAW_HOME}/skills/content-engine/SKILL.md"
        if [ -d "$SKILL_DIR/scripts" ]; then
            cp -r "$SKILL_DIR/scripts" "${OPENCLAW_HOME}/skills/content-engine/"
        fi
    else
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p /home/node/.openclaw/skills/content-engine"
        docker cp "$SKILL_DIR/SKILL.md" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/SKILL.md"
        if [ -d "$SKILL_DIR/scripts" ]; then
            docker cp "$SKILL_DIR/scripts" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/"
        fi
        docker exec "$CONTAINER_NAME" bash -c "chown -R node:node /home/node/.openclaw/skills/content-engine" 2>/dev/null || true
    fi

    log "  content-engine skill installed"
}

# ============================================================================
# [2.5/7] Set up the default agent with browser + content identity
# ============================================================================
create_agent() {
    log "=== [2.5/7] Setting Up Agent: ${AGENT_EMOJI} ${AGENT_NAME} ==="

    local identity_src="${SCRIPT_DIR}/IDENTITY.md"
    local identity_tmp=""

    # Generate IDENTITY.md with the chosen agent name and emoji
    if [ -f "$identity_src" ]; then
        identity_tmp=$(mktemp)
        sed "s/^- \*\*Name:\*\*.*/- **Name:** ${AGENT_NAME}/" "$identity_src" \
            | sed "s/^- \*\*Emoji:\*\*.*/- **Emoji:** ${AGENT_EMOJI}/" > "$identity_tmp"
    else
        warn "  IDENTITY.md template not found — skipping"
        return
    fi

    if [ "$INSTALL_MODE" = "local" ]; then
        # Find the main agent's workspace
        local agent_ws="${OPENCLAW_HOME}/workspace"
        if [ -n "$OC_BIN" ]; then
            local cfg_ws
            cfg_ws=$("$OC_BIN" config get agents.defaults.workspace 2>/dev/null || true)
            if [ -n "$cfg_ws" ] && [ "$cfg_ws" != "undefined" ]; then
                agent_ws="$cfg_ws"
            fi
        fi
        mkdir -p "$agent_ws"

        # Deploy IDENTITY.md to workspace
        if [ -f "$agent_ws/IDENTITY.md" ]; then
            cp "$agent_ws/IDENTITY.md" "$agent_ws/IDENTITY.md.bak"
            log "  Backed up existing IDENTITY.md"
        fi
        cp "$identity_tmp" "$agent_ws/IDENTITY.md"
        log "  IDENTITY.md deployed to $agent_ws/"

        # Set agent identity on the DEFAULT (main) agent
        # This is the agent that handles all Telegram/Discord messages
        if [ -n "$OC_BIN" ]; then
            log "  Registering identity: ${AGENT_EMOJI} ${AGENT_NAME}..."
            "$OC_BIN" agents set-identity \
                --agent main \
                --name "$AGENT_NAME" \
                --emoji "$AGENT_EMOJI" \
                --identity-file "$agent_ws/IDENTITY.md" \
                2>/dev/null || {
                    "$OC_BIN" agents set-identity \
                        --agent main \
                        --name "$AGENT_NAME" \
                        --emoji "$AGENT_EMOJI" \
                        2>/dev/null || warn "  Could not set identity via CLI"
                }
        fi
    else
        # Docker mode
        local docker_ws="/home/node/.openclaw/workspace"
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p $docker_ws" 2>/dev/null || true

        docker exec "$CONTAINER_NAME" bash -c "test -f $docker_ws/IDENTITY.md && cp $docker_ws/IDENTITY.md $docker_ws/IDENTITY.md.bak" 2>/dev/null || true
        docker cp "$identity_tmp" "${CONTAINER_NAME}:$docker_ws/IDENTITY.md"
        docker exec "$CONTAINER_NAME" bash -c "chown node:node $docker_ws/IDENTITY.md" 2>/dev/null || true

        docker exec -u node "$CONTAINER_NAME" openclaw agents set-identity \
            --agent main \
            --name "$AGENT_NAME" \
            --emoji "$AGENT_EMOJI" \
            --identity-file "$docker_ws/IDENTITY.md" \
            2>/dev/null || warn "  Could not set identity in container"
    fi

    # Clean up temp file
    [ -n "$identity_tmp" ] && rm -f "$identity_tmp" 2>/dev/null || true

    # Verify
    if [ -n "$OC_BIN" ] && [ "$INSTALL_MODE" = "local" ]; then
        local verify_out
        verify_out=$("$OC_BIN" agents list 2>/dev/null || true)
        if echo "$verify_out" | grep -q "$AGENT_NAME"; then
            log "  Agent ${AGENT_EMOJI} ${AGENT_NAME} is the default agent"
            log "  All Telegram/Discord messages will go to this agent"
        else
            warn "  Agent name not visible yet (will apply after gateway restart)"
        fi
    fi
}

# ============================================================================
# [3/7] Configure OpenClaw for full autonomy
# ============================================================================
configure_openclaw() {
    log "=== [3/7] Configuring OpenClaw for Full Autonomy ==="

    if [ "$INSTALL_MODE" = "local" ] && [ -z "$OC_BIN" ]; then
        warn "  openclaw CLI not found — writing config via JSON fallback"
        configure_via_json
        return
    fi

    if [ "$INSTALL_MODE" = "local" ] && [ -n "$OC_BIN" ]; then
        configure_via_cli
    elif [ "$INSTALL_MODE" = "docker" ]; then
        configure_via_cli
    fi
}

configure_via_cli() {
    # --- PLUGINS ---
    # Enable lobster (browser), llm-task (background), open-prose (text), voice-call (audio)
    log "  [Plugins] Enabling all required plugins..."
    oc_config set plugins.entries.lobster.enabled true
    oc_config set plugins.entries.llm-task.enabled true
    oc_config set plugins.entries.open-prose.enabled true
    oc_config set plugins.entries.voice-call.enabled true

    # Install lobster plugin if not already installed (provides browser tool)
    log "  [Plugins] Ensuring lobster plugin is installed..."
    oc_cmd plugins install lobster 2>/dev/null || true

    # Install Playwright browsers (lobster needs these to function)
    log "  [Browser] Installing Playwright browser binaries..."
    if command -v npx >/dev/null 2>&1; then
        npx playwright install chromium 2>/dev/null || true
    fi
    # Also try OpenClaw's built-in browser setup
    oc_cmd browser setup 2>/dev/null || true
    oc_cmd browser install 2>/dev/null || true

    # --- TOOLS: FULL ACCESS ---
    log "  [Tools] Allowing ALL tools for ALL channels..."
    oc_config set tools.allow '["*"]'

    # Elevated tools — allow from ALL channels (telegram, discord, etc.)
    oc_config set tools.elevated.enabled true
    oc_config set tools.elevated.allowFrom.telegram '["*"]'
    oc_config set tools.elevated.allowFrom.discord '["*"]'

    # Exec tool — 30min timeout for long-running tasks (FFmpeg, downloads)
    oc_config set tools.exec.timeoutSec 1800
    oc_config set tools.exec.notifyOnExit true

    # --- AGENT DEFAULTS ---
    log "  [Agent] Setting defaults (sandbox off, concurrency, compaction)..."
    oc_config set agents.defaults.sandbox.mode off
    oc_config set agents.defaults.maxConcurrent 4
    oc_config set agents.defaults.subagents.maxConcurrent 8
    oc_config set agents.defaults.compaction.mode safeguard

    if [ "$INSTALL_MODE" = "local" ]; then
        local ws
        ws=$(echo "${OPENCLAW_HOME}/workspace" | sed 's|\\|/|g')
        oc_config set agents.defaults.workspace "$ws"
    fi

    # --- COMMANDS ---
    log "  [Commands] native + nativeSkills = auto..."
    oc_config set commands.native auto
    oc_config set commands.nativeSkills auto

    # --- SKILLS ---
    oc_config set skills.install.nodeManager npm

    # --- MESSAGES: ack reactions for group mentions ---
    oc_config set messages.ackReactionScope group-mentions

    # --- BROWSER PROFILE ---
    # "openclaw" = headless Playwright; works without Chrome/Chromium installed
    log "  [Browser] Setting default profile to 'openclaw' (headless Playwright)..."
    oc_config set browser.defaultProfile openclaw

    # Create the headless profile if it doesn't exist
    oc_cmd browser create-profile --name openclaw --driver openclaw --color "#FF4500" 2>/dev/null || true

    # --- VERIFY BROWSER TOOL ---
    log "  [Browser] Verifying browser tool availability..."
    local tools_out
    tools_out=$(oc_cmd tools list 2>/dev/null || true)
    if echo "$tools_out" | grep -qi "browser"; then
        log "  Browser tool: AVAILABLE"
    else
        warn "  Browser tool not visible yet — will be available after gateway restart"
        # Try activating lobster one more time
        oc_cmd plugins activate lobster 2>/dev/null || true
    fi

    log "  All settings applied"
}

configure_via_json() {
    local config_file="${OPENCLAW_HOME}/openclaw.json"
    local ws
    ws=$(echo "${OPENCLAW_HOME}/workspace" | sed 's|\\|/|g')

    # Try Node.js first, then Python, then manual
    if command -v node >/dev/null 2>&1; then
        log "  Writing config via Node.js..."
        node -e "
var fs = require('fs');
var p = process.argv[1];
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
cfg.tools.elevated.allowFrom.telegram = ['*'];
cfg.tools.elevated.allowFrom.discord = ['*'];
if (!cfg.tools.exec) cfg.tools.exec = {};
cfg.tools.exec.timeoutSec = 1800;
cfg.tools.exec.notifyOnExit = true;
if (!cfg.messages) cfg.messages = {};
cfg.messages.ackReactionScope = 'group-mentions';
if (!cfg.agents) cfg.agents = {};
if (!cfg.agents.defaults) cfg.agents.defaults = {};
cfg.agents.defaults.sandbox = { mode: 'off' };
cfg.agents.defaults.maxConcurrent = 4;
cfg.agents.defaults.subagents = { maxConcurrent: 8 };
cfg.agents.defaults.compaction = { mode: 'safeguard' };
cfg.agents.defaults.workspace = process.argv[2];
if (!cfg.commands) cfg.commands = {};
cfg.commands.native = 'auto';
cfg.commands.nativeSkills = 'auto';
if (!cfg.skills) cfg.skills = {};
cfg.skills.install = { nodeManager: 'npm' };
if (!cfg.browser) cfg.browser = {};
cfg.browser.defaultProfile = 'openclaw';
fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
" "$config_file" "$ws" 2>&1 && log "  Config written" || err "  Node.js config write failed"

    elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
        local py
        if command -v python3 >/dev/null 2>&1; then py="python3"; else py="python"; fi
        log "  Writing config via Python..."
        "$py" - "$config_file" "$ws" <<'PYEOF'
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
cfg["tools"]["elevated"]["allowFrom"]["telegram"] = ["*"]
cfg["tools"]["elevated"]["allowFrom"]["discord"] = ["*"]
cfg["tools"].setdefault("exec", {})
cfg["tools"]["exec"]["timeoutSec"] = 1800
cfg["tools"]["exec"]["notifyOnExit"] = True
cfg.setdefault("agents", {}).setdefault("defaults", {})
cfg["agents"]["defaults"]["sandbox"] = {"mode": "off"}
cfg["agents"]["defaults"]["maxConcurrent"] = 4
cfg["agents"]["defaults"]["subagents"] = {"maxConcurrent": 8}
cfg["agents"]["defaults"]["compaction"] = {"mode": "safeguard"}
cfg["agents"]["defaults"]["workspace"] = ws
cfg.setdefault("commands", {})
cfg["commands"]["native"] = "auto"
cfg["commands"]["nativeSkills"] = "auto"
cfg.setdefault("skills", {})
cfg["skills"]["install"] = {"nodeManager": "npm"}
cfg.setdefault("messages", {})
cfg["messages"]["ackReactionScope"] = "group-mentions"
cfg.setdefault("browser", {})
cfg["browser"]["defaultProfile"] = "openclaw"
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
        log "  Config written" || err "  Python config write failed"
    else
        err "  No node or python found. Install Node.js or the openclaw CLI first."
        err "  Config was NOT written. You must configure manually."
    fi
}

# ============================================================================
# [4/7] Deploy credentials template
# ============================================================================
deploy_credentials() {
    log "=== [4/7] Setting Up Credentials ==="

    if [ "$INSTALL_MODE" = "local" ]; then
        mkdir -p "${OPENCLAW_HOME}/sessions" "${OPENCLAW_HOME}/workspace"
        if [ -f "${OPENCLAW_HOME}/credentials.json" ]; then
            log "  credentials.json already exists — keeping it"
        else
            cp "$CREDS_TEMPLATE" "${OPENCLAW_HOME}/credentials.json"
            # chmod 600 only on Unix (skip on Windows where it's unsupported)
            if [ "$OS_TYPE" != "windows" ]; then
                chmod 600 "${OPENCLAW_HOME}/credentials.json" 2>/dev/null || true
            fi
            warn "  credentials.json created at:"
            warn "  ${OPENCLAW_HOME}/credentials.json"
            warn "  >>> EDIT THIS FILE and add your platform logins <<<"
        fi
    else
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p /home/node/.openclaw/sessions /home/node/.openclaw/workspace" 2>/dev/null || true
        if docker exec "$CONTAINER_NAME" bash -c "test -f /home/node/.openclaw/credentials.json" 2>/dev/null; then
            log "  credentials.json already exists — keeping it"
        else
            docker cp "$CREDS_TEMPLATE" "${CONTAINER_NAME}:/home/node/.openclaw/credentials.json"
            docker exec "$CONTAINER_NAME" bash -c "chown node:node /home/node/.openclaw/credentials.json && chmod 600 /home/node/.openclaw/credentials.json" 2>/dev/null || true
            warn "  credentials.json deployed. Edit it:"
            warn "  docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json"
        fi
    fi
}

# ============================================================================
# [5/7] Reindex memory
# ============================================================================
reindex_memory() {
    log "=== [5/7] Indexing Memory ==="
    if [ -n "$OC_BIN" ] || [ "$INSTALL_MODE" = "docker" ]; then
        oc_cmd memory index --force
        log "  Memory indexed (embedding warnings are normal without an embedding API key)"
    else
        warn "  Skipped — openclaw CLI not available"
        warn "  Run manually later: openclaw memory index --force"
    fi
}

# ============================================================================
# [6/7] Full restart of OpenClaw gateway to load new config
# ============================================================================
restart_gateway() {
    log "=== [6/7] Full OpenClaw Restart ==="

    # --- DOCKER ---
    if [ "$INSTALL_MODE" = "docker" ]; then
        log "  Stopping container ${CONTAINER_NAME}..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        sleep 2
        log "  Starting container ${CONTAINER_NAME}..."
        docker start "$CONTAINER_NAME" 2>/dev/null || { err "  Failed to start container"; return; }
        log "  Waiting for gateway inside container..."
        sleep 10
        log "  Container restarted"
        return
    fi

    # --- LOCAL ---
    if [ -z "$OC_BIN" ]; then
        warn "  openclaw CLI not found — restart manually after install"
        return
    fi

    # ---- STEP 1: Kill everything OpenClaw ----
    log "  Killing all OpenClaw processes..."

    # Try graceful stop first
    "$OC_BIN" gateway stop 2>/dev/null || true
    sleep 1

    # Get gateway port from config (default 18789)
    local gw_port=18789
    local cfg_port
    cfg_port=$("$OC_BIN" config get gateway.port 2>/dev/null || true)
    if [ -n "$cfg_port" ] && echo "$cfg_port" | grep -qE '^[0-9]+$'; then
        gw_port="$cfg_port"
    fi

    case "$OS_TYPE" in
        windows)
            # Kill by port — most reliable on Windows
            local pids
            pids=$(netstat.exe -ano 2>/dev/null | grep ":${gw_port} " | grep "LISTEN" | awk '{print $5}' | sort -u)
            for pid in $pids; do
                if [ -n "$pid" ] && [ "$pid" != "0" ]; then
                    log "  Killing PID $pid (port $gw_port)..."
                    taskkill.exe //PID "$pid" //F 2>/dev/null || true
                fi
            done
            # Also kill any node process running openclaw gateway
            taskkill.exe //IM "node.exe" //FI "WINDOWTITLE eq openclaw*" //F 2>/dev/null || true
            # Kill by command line match (catches all openclaw node processes)
            wmic.exe process where "CommandLine like '%openclaw%gateway%'" call terminate 2>/dev/null || true
            ;;
        linux|wsl)
            # Kill by port
            if command -v fuser >/dev/null 2>&1; then
                fuser -k "${gw_port}/tcp" 2>/dev/null || true
            elif command -v lsof >/dev/null 2>&1; then
                lsof -ti :"$gw_port" 2>/dev/null | xargs kill -9 2>/dev/null || true
            fi
            # Kill any openclaw gateway process
            pkill -f "openclaw.*gateway" 2>/dev/null || true
            ;;
        macos)
            # Kill by port
            if command -v lsof >/dev/null 2>&1; then
                lsof -ti :"$gw_port" 2>/dev/null | xargs kill -9 2>/dev/null || true
            fi
            # Kill any openclaw gateway process
            pkill -f "openclaw.*gateway" 2>/dev/null || true
            ;;
    esac

    # Wait for port to be free
    sleep 3
    log "  All OpenClaw processes killed"

    # ---- STEP 2: Start gateway fresh ----
    log "  Starting OpenClaw gateway..."

    # Use --force to claim the port even if something lingers
    case "$OS_TYPE" in
        windows)
            "$OC_BIN" gateway --force >/dev/null 2>&1 &
            disown "$!" 2>/dev/null || true
            ;;
        *)
            nohup "$OC_BIN" gateway --force >/dev/null 2>&1 &
            disown 2>/dev/null || true
            ;;
    esac

    # ---- STEP 3: Wait for gateway to be ready ----
    log "  Waiting for gateway to come online..."
    local attempts=0
    local gw_up=false
    while [ "$attempts" -lt 15 ]; do
        sleep 2
        attempts=$((attempts + 1))
        local probe
        probe=$("$OC_BIN" gateway status 2>&1 || true)
        if echo "$probe" | grep -q "RPC probe: ok"; then
            gw_up=true
            break
        fi
    done

    if $gw_up; then
        log "  OpenClaw gateway is running (new config loaded)"

        # Verify browser service loaded
        local browser_status
        browser_status=$("$OC_BIN" browser status 2>&1 || true)
        if echo "$browser_status" | grep -qi "enabled: true"; then
            log "  Browser tool: ACTIVE"
        else
            warn "  Browser tool status unclear — test with: openclaw browser status"
        fi
    else
        err "  Gateway did not start within 30 seconds"
        err "  Start manually:"
        err "    $OC_BIN gateway --force"
    fi
}

# ============================================================================
# [7/7] Verify
# ============================================================================
verify() {
    log "=== [7/7] Verifying Installation ==="

    local ok=true

    if [ "$INSTALL_MODE" = "local" ]; then
        # Knowledge
        local kcount=0
        for f in "${OPENCLAW_HOME}/memory/content-engine/"*.md; do
            [ -f "$f" ] && kcount=$((kcount + 1))
        done
        if [ "$kcount" -gt 0 ]; then
            log "  Knowledge: ${kcount} files"
        else
            err "  Knowledge: NOT FOUND"; ok=false
        fi

        # Skill
        if [ -f "${OPENCLAW_HOME}/skills/content-engine/SKILL.md" ]; then
            log "  Skill: INSTALLED"
        else
            err "  Skill: NOT FOUND"; ok=false
        fi

        # Credentials
        if [ -f "${OPENCLAW_HOME}/credentials.json" ]; then
            log "  Credentials: PRESENT (remember to fill in your logins)"
        else
            warn "  Credentials: NOT FOUND"
        fi

        # Config (only if CLI available)
        if [ -n "$OC_BIN" ]; then
            local lobster
            lobster=$("$OC_BIN" config get plugins.entries.lobster.enabled 2>/dev/null || echo "?")
            if [ "$lobster" = "true" ]; then
                log "  Plugin lobster (browser): ENABLED"
            else
                warn "  Plugin lobster: $lobster"
            fi

            local llmtask
            llmtask=$("$OC_BIN" config get plugins.entries.llm-task.enabled 2>/dev/null || echo "?")
            if [ "$llmtask" = "true" ]; then
                log "  Plugin llm-task: ENABLED"
            else
                warn "  Plugin llm-task: $llmtask"
            fi

            local sandbox
            sandbox=$("$OC_BIN" config get agents.defaults.sandbox.mode 2>/dev/null || echo "?")
            if [ "$sandbox" = "off" ]; then
                log "  Sandbox: OFF"
            else
                warn "  Sandbox: $sandbox"
            fi

            # Skill readiness
            local skill_out
            skill_out=$("$OC_BIN" skills list 2>/dev/null || true)
            if echo "$skill_out" | grep -q "content-engine"; then
                if echo "$skill_out" | grep "content-engine" | grep -q "ready"; then
                    log "  Skill status: READY"
                else
                    warn "  Skill visible but not ready (restart gateway)"
                fi
            else
                warn "  Skill not visible yet (restart gateway)"
            fi
        fi

        # Directories
        [ -d "${OPENCLAW_HOME}/workspace" ] && log "  Workspace: OK" || warn "  Workspace: missing"
        [ -d "${OPENCLAW_HOME}/sessions" ] && log "  Sessions: OK" || warn "  Sessions: missing"
    else
        # Docker verification
        local c
        c=$(docker exec "$CONTAINER_NAME" bash -c "ls -1 /home/node/.openclaw/memory/content-engine/*.md 2>/dev/null | wc -l" || echo "0")
        if [ "$c" -gt 0 ]; then
            log "  Knowledge: ${c} files"
        else
            err "  Knowledge: NOT FOUND"; ok=false
        fi
        docker exec "$CONTAINER_NAME" bash -c "test -f /home/node/.openclaw/skills/content-engine/SKILL.md" 2>/dev/null \
            && log "  Skill: INSTALLED" || { err "  Skill: NOT FOUND"; ok=false; }
        docker exec "$CONTAINER_NAME" bash -c "test -f /home/node/.openclaw/credentials.json" 2>/dev/null \
            && log "  Credentials: PRESENT" || warn "  Credentials: NOT FOUND"
    fi

    # --- FULL DIAGNOSTIC DUMP ---
    # This helps debug when the browser tool isn't loading
    if [ -n "$OC_BIN" ] && [ "$INSTALL_MODE" = "local" ]; then
        echo ""
        log "  ─── DIAGNOSTIC: Tool & Plugin Status ───"

        # List all available tools
        log "  Available tools:"
        local all_tools
        all_tools=$("$OC_BIN" tools list 2>&1 || echo "(tools list failed)")
        echo "$all_tools" | head -30 | while IFS= read -r line; do
            echo "    $line"
        done

        # List plugins
        log "  Plugin status:"
        local all_plugins
        all_plugins=$("$OC_BIN" plugins list 2>&1 || echo "(plugins list failed)")
        echo "$all_plugins" | head -20 | while IFS= read -r line; do
            echo "    $line"
        done

        # Browser status
        log "  Browser status:"
        local bstatus
        bstatus=$("$OC_BIN" browser status 2>&1 || echo "(browser status failed)")
        echo "$bstatus" | head -10 | while IFS= read -r line; do
            echo "    $line"
        done

        # Agent identity
        log "  Agent identity:"
        local agent_info
        agent_info=$("$OC_BIN" agents list 2>&1 || echo "(agents list failed)")
        echo "$agent_info" | head -10 | while IFS= read -r line; do
            echo "    $line"
        done

        # Config dump (key sections)
        log "  Key config values:"
        for key in plugins.entries.lobster.enabled browser.defaultProfile tools.allow agents.defaults.sandbox.mode tools.elevated.enabled; do
            local val
            val=$("$OC_BIN" config get "$key" 2>/dev/null || echo "?")
            echo "    $key = $val"
        done

        log "  ─── END DIAGNOSTIC ───"
    fi

    echo ""
    if $ok; then
        log "  Verification PASSED"
    else
        err "  Some checks failed — review output above"
    fi
}

# ============================================================================
# Summary
# ============================================================================
print_summary() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  Content Engine — Installation Complete${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    local mode_upper
    mode_upper=$(echo "$INSTALL_MODE" | tr '[:lower:]' '[:upper:]')
    echo -e "  ${GREEN}Mode:${NC}  ${mode_upper} on ${OS_TYPE} (browser automation, no API keys)"
    echo ""
    echo -e "  ${GREEN}Agent:${NC}  ${AGENT_EMOJI} ${AGENT_NAME}"
    echo ""
    echo -e "  ${GREEN}Installed:${NC}"
    echo "    - Agent: ${AGENT_EMOJI} ${AGENT_NAME} (with IDENTITY.md)"
    echo "    - 13 knowledge files (memory/content-engine/)"
    echo "    - content-engine skill (SKILL.md)"
    echo "    - credentials.json template"
    echo ""
    echo -e "  ${GREEN}Configured:${NC}"
    echo "    - lobster plugin        (browser tool for agent)"
    echo "    - llm-task plugin       (background task execution)"
    echo "    - open-prose plugin     (text processing)"
    echo "    - voice-call plugin     (audio capabilities)"
    echo '    - tools.allow = ["*"]   (full tool access)'
    echo "    - tools.elevated        (elevated from ALL channels)"
    echo "    - exec timeout 30min    (long-running tasks)"
    echo "    - sandbox = off         (browser + filesystem)"
    echo "    - 4 agents / 8 subs    (parallel execution)"
    echo "    - Playwright browsers   (headless Chromium)"
    echo "    - workspace directory   (asset storage)"
    echo ""

    echo -e "  ${CYAN}Next Steps:${NC}"
    echo ""
    echo -e "    ${BOLD}1.${NC} Edit credentials.json with your platform logins"
    if [ "$INSTALL_MODE" = "local" ]; then
        echo "       ${OPENCLAW_HOME}/credentials.json"
    else
        echo "       docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json"
    fi
    echo ""
    echo -e "    ${BOLD}2.${NC} Restart the gateway to apply config"
    if [ "$INSTALL_MODE" = "docker" ]; then
        echo "       docker restart ${CONTAINER_NAME}"
    else
        echo "       openclaw gateway stop && openclaw gateway"
    fi
    echo ""
    echo -e "    ${BOLD}3.${NC} Test via Telegram:"
    echo '       "Open the browser and go to chat.openai.com"'
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================
main() {
    detect_os
    log "Detected OS: ${OS_TYPE}"

    # Validate knowledge directory exists
    local md_count=0
    for f in "$KNOWLEDGE_DIR"/*.md; do [ -f "$f" ] && md_count=$((md_count + 1)); done
    if [ "$md_count" -eq 0 ]; then
        err "No knowledge files found in: $KNOWLEDGE_DIR"
        err "Run this script from the openclaw-content-engine directory."
        exit 1
    fi

    if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
        err "Skill not found: $SKILL_DIR/SKILL.md"
        exit 1
    fi

    if [ ! -f "$CREDS_TEMPLATE" ]; then
        err "Credentials template not found: $CREDS_TEMPLATE"
        exit 1
    fi

    detect_installations
    install_knowledge
    install_skill
    create_agent
    configure_openclaw
    deploy_credentials
    reindex_memory
    restart_gateway
    verify
    print_summary
}

main "$@"
