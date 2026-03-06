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
    log "  [Plugins] lobster (browser automation)..."
    oc_config set plugins.entries.lobster.enabled true
    log "  [Plugins] llm-task (background tasks)..."
    oc_config set plugins.entries.llm-task.enabled true

    log "  [Tools] allow all..."
    oc_config set tools.allow '["*"]'
    log "  [Tools] elevated tools..."
    oc_config set tools.elevated.enabled true
    log "  [Tools] exec timeout 30min..."
    oc_config set tools.exec.timeoutSec 1800
    log "  [Tools] exec notify on exit..."
    oc_config set tools.exec.notifyOnExit true

    log "  [Agent] sandbox off..."
    oc_config set agents.defaults.sandbox.mode off
    log "  [Agent] max concurrent 4..."
    oc_config set agents.defaults.maxConcurrent 4
    log "  [Agent] subagents max 8..."
    oc_config set agents.defaults.subagents.maxConcurrent 8
    log "  [Agent] compaction safeguard..."
    oc_config set agents.defaults.compaction.mode safeguard

    if [ "$INSTALL_MODE" = "local" ]; then
        log "  [Agent] workspace..."
        # Normalize path (forward slashes for JSON)
        local ws
        ws=$(echo "${OPENCLAW_HOME}/workspace" | sed 's|\\|/|g')
        oc_config set agents.defaults.workspace "$ws"
    fi

    log "  [Commands] native + nativeSkills = auto..."
    oc_config set commands.native auto
    oc_config set commands.nativeSkills auto

    log "  [Skills] nodeManager = npm..."
    oc_config set skills.install.nodeManager npm

    # --- BROWSER PROFILE ---
    # Set "openclaw" (headless Playwright) as default browser profile
    # This works on fresh machines even without Chrome/Chromium installed
    log "  [Browser] Setting default profile to 'openclaw' (headless Playwright)..."
    oc_config set browser.defaultProfile openclaw

    # Ensure the headless profile exists
    log "  [Browser] Creating headless browser profile..."
    oc_cmd browser create-profile --name openclaw --driver openclaw --color "#FF4500" 2>/dev/null || true

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
if (!cfg.tools) cfg.tools = {};
cfg.tools.allow = ['*'];
if (!cfg.tools.elevated) cfg.tools.elevated = {};
cfg.tools.elevated.enabled = true;
if (!cfg.tools.exec) cfg.tools.exec = {};
cfg.tools.exec.timeoutSec = 1800;
cfg.tools.exec.notifyOnExit = true;
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
cfg.setdefault("tools", {})
cfg["tools"]["allow"] = ["*"]
cfg["tools"].setdefault("elevated", {})["enabled"] = True
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
# [6/7] Restart gateway to load new config
# ============================================================================
restart_gateway() {
    log "=== [6/7] Restarting Gateway (loading new config) ==="

    if [ "$INSTALL_MODE" = "docker" ]; then
        log "  Restarting Docker container ${CONTAINER_NAME}..."
        docker restart "$CONTAINER_NAME" 2>/dev/null && log "  Container restarted" || warn "  Could not restart container — do it manually: docker restart ${CONTAINER_NAME}"
        log "  Waiting for gateway to come back..."
        sleep 8
        return
    fi

    if [ -z "$OC_BIN" ]; then
        warn "  openclaw CLI not found — restart gateway manually after install"
        return
    fi

    # Step 1: Find and kill the running gateway process
    log "  Stopping gateway..."
    "$OC_BIN" gateway stop 2>/dev/null || true
    sleep 2

    # Kill any remaining openclaw gateway process by port
    local gw_pid=""
    case "$OS_TYPE" in
        windows)
            # Windows: use netstat to find PID on port 18789
            gw_pid=$(netstat -ano 2>/dev/null | grep ":18789 " | grep "LISTENING" | awk '{print $5}' | head -1)
            if [ -n "$gw_pid" ] && [ "$gw_pid" != "0" ]; then
                log "  Killing gateway process (PID $gw_pid)..."
                taskkill //PID "$gw_pid" //F 2>/dev/null || true
                sleep 2
            fi
            ;;
        linux|wsl|macos)
            # Unix: use lsof or fuser
            if command -v lsof >/dev/null 2>&1; then
                gw_pid=$(lsof -ti :18789 2>/dev/null | head -1)
            elif command -v fuser >/dev/null 2>&1; then
                gw_pid=$(fuser 18789/tcp 2>/dev/null | tr -d ' ')
            fi
            if [ -n "$gw_pid" ]; then
                log "  Killing gateway process (PID $gw_pid)..."
                kill "$gw_pid" 2>/dev/null || true
                sleep 2
                # Force kill if still running
                kill -0 "$gw_pid" 2>/dev/null && kill -9 "$gw_pid" 2>/dev/null || true
                sleep 1
            fi
            ;;
    esac

    # Step 2: Start gateway fresh in background
    log "  Starting gateway with new config..."
    case "$OS_TYPE" in
        windows)
            # On Windows/Git Bash, use start to detach
            "$OC_BIN" gateway 2>/dev/null &
            local bg_pid=$!
            disown "$bg_pid" 2>/dev/null || true
            ;;
        *)
            nohup "$OC_BIN" gateway >/dev/null 2>&1 &
            disown 2>/dev/null || true
            ;;
    esac

    # Step 3: Wait and verify
    log "  Waiting for gateway to start..."
    local attempts=0
    local max_attempts=12
    local gw_up=false
    while [ "$attempts" -lt "$max_attempts" ]; do
        sleep 2
        attempts=$((attempts + 1))
        local status_out
        status_out=$("$OC_BIN" gateway status 2>&1 || true)
        if echo "$status_out" | grep -qi "RPC probe: ok\|Listening"; then
            gw_up=true
            break
        fi
    done

    if $gw_up; then
        log "  Gateway is running with new config"
    else
        warn "  Gateway may not have started — check with: openclaw gateway status"
        warn "  You can start it manually: openclaw gateway"
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
    echo -e "  ${GREEN}Installed:${NC}"
    echo "    - 13 knowledge files (memory/content-engine/)"
    echo "    - content-engine skill (SKILL.md)"
    echo "    - credentials.json template"
    echo ""
    echo -e "  ${GREEN}Configured:${NC}"
    echo "    - lobster plugin        (browser tool for agent)"
    echo "    - llm-task plugin       (background task execution)"
    echo '    - tools.allow = ["*"]   (full tool access)'
    echo "    - tools.elevated        (elevated from Telegram)"
    echo "    - exec timeout 30min    (long-running tasks)"
    echo "    - sandbox = off         (browser + filesystem)"
    echo "    - 4 agents / 8 subs    (parallel execution)"
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
    configure_openclaw
    deploy_credentials
    reindex_memory
    restart_gateway
    verify
    print_summary
}

main "$@"
