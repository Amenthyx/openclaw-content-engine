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
DOCKER_COMPOSE_DIR=""

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
# Ensure Docker daemon + container are running
# ============================================================================
ensure_docker_ready() {
    # ---- Step 1: Find docker-compose.yml ----
    local candidates=(
        "${SCRIPT_DIR}/../OpenClaw-Docker"
        "${SCRIPT_DIR}/../openClaw-Docker"
        "${SCRIPT_DIR}/../openclaw-docker"
    )
    # Also check common Desktop locations
    local desktop=""
    case "$OS_TYPE" in
        windows)
            if [ -n "${USERPROFILE:-}" ]; then
                desktop="$(echo "$USERPROFILE" | sed 's|\\|/|g')/Desktop"
            else
                desktop="$HOME/Desktop"
            fi
            ;;
        *)
            desktop="$HOME/Desktop"
            ;;
    esac
    if [ -n "$desktop" ]; then
        candidates+=("$desktop/OpenClaw-Docker" "$desktop/openClaw-Docker" "$desktop/openclaw-docker")
    fi

    DOCKER_COMPOSE_DIR=""
    for d in "${candidates[@]}"; do
        if [ -f "$d/docker-compose.yml" ]; then
            DOCKER_COMPOSE_DIR="$(cd "$d" && pwd)"
            break
        fi
    done

    if [ -z "$DOCKER_COMPOSE_DIR" ]; then
        warn "  Could not find OpenClaw docker-compose.yml automatically."
        printf "  %bPath to OpenClaw-Docker directory:%b " "$BOLD" "$NC"
        read -r custom_docker_dir
        if [ -f "$custom_docker_dir/docker-compose.yml" ]; then
            DOCKER_COMPOSE_DIR="$(cd "$custom_docker_dir" && pwd)"
        else
            err "  No docker-compose.yml found at: $custom_docker_dir"
            err "  Cannot start Docker container."
            return 1
        fi
    fi
    log "  Docker compose dir: ${DOCKER_COMPOSE_DIR}"

    # ---- Step 2: Ensure Docker daemon is running ----
    if ! docker info >/dev/null 2>&1; then
        log "  Docker daemon is not running — starting Docker Desktop..."
        case "$OS_TYPE" in
            windows)
                # Try common Docker Desktop paths
                local dd_path=""
                for p in \
                    "$(echo "${PROGRAMFILES:-}" | sed 's|\\|/|g')/Docker/Docker/Docker Desktop.exe" \
                    "/c/Program Files/Docker/Docker/Docker Desktop.exe" \
                    "$(echo "${LOCALAPPDATA:-}" | sed 's|\\|/|g')/Docker/Docker Desktop.exe"; do
                    if [ -f "$p" ]; then dd_path="$p"; break; fi
                done
                if [ -n "$dd_path" ]; then
                    log "  Launching: $dd_path"
                    "$dd_path" &>/dev/null &
                    disown "$!" 2>/dev/null || true
                else
                    # Fallback: try start command
                    cmd.exe /c "start \"\" \"C:\\Program Files\\Docker\\Docker\\Docker Desktop.exe\"" 2>/dev/null || true
                fi
                ;;
            macos)
                open -a "Docker" 2>/dev/null || open -a "Docker Desktop" 2>/dev/null || true
                ;;
            linux)
                sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
                ;;
            wsl)
                # WSL typically uses Docker Desktop from Windows side
                cmd.exe /c "start \"\" \"C:\\Program Files\\Docker\\Docker\\Docker Desktop.exe\"" 2>/dev/null || true
                ;;
        esac

        # Wait for Docker daemon to be ready
        log "  Waiting for Docker daemon..."
        local docker_attempts=0
        while [ "$docker_attempts" -lt 30 ]; do
            sleep 3
            docker_attempts=$((docker_attempts + 1))
            if docker info >/dev/null 2>&1; then
                log "  Docker daemon is ready"
                break
            fi
            if [ "$((docker_attempts % 5))" -eq 0 ]; then
                log "  Still waiting for Docker... (${docker_attempts}/30)"
            fi
        done

        if ! docker info >/dev/null 2>&1; then
            err "  Docker daemon did not start within 90 seconds."
            err "  Please start Docker Desktop manually and re-run this script."
            return 1
        fi
    else
        log "  Docker daemon: running"
    fi

    # ---- Step 3: Ensure container is running ----
    # Get the container name from docker-compose.yml
    local compose_container=""
    compose_container=$(grep 'container_name:' "$DOCKER_COMPOSE_DIR/docker-compose.yml" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '[:space:]')
    compose_container="${compose_container:-clawbot}"

    if docker ps --format '{{.Names}}' | grep -q "^${compose_container}$"; then
        log "  Container '${compose_container}' is already running"
        CONTAINER_NAME="$compose_container"
        return 0
    fi

    # Check if container exists but is stopped
    if docker ps -a --format '{{.Names}}' | grep -q "^${compose_container}$"; then
        log "  Container '${compose_container}' exists but is stopped — starting..."
        docker start "$compose_container" 2>/dev/null || {
            log "  Start failed — rebuilding with docker compose..."
            (cd "$DOCKER_COMPOSE_DIR" && docker compose up -d --build) || {
                err "  Failed to start container. Check docker-compose.yml"
                return 1
            }
        }
    else
        log "  Container '${compose_container}' does not exist — building and starting..."
        (cd "$DOCKER_COMPOSE_DIR" && docker compose up -d --build) || {
            err "  Failed to build/start container. Check docker-compose.yml and .env"
            return 1
        }
    fi

    # ---- Step 4: Wait for container healthcheck ----
    log "  Waiting for container to be healthy (up to 90s)..."
    local health_attempts=0
    while [ "$health_attempts" -lt 30 ]; do
        sleep 3
        health_attempts=$((health_attempts + 1))
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$compose_container" 2>/dev/null || echo "unknown")
        case "$health" in
            healthy)
                log "  Container '${compose_container}' is healthy"
                CONTAINER_NAME="$compose_container"
                return 0
                ;;
            unhealthy)
                err "  Container is unhealthy — check logs: docker logs $compose_container"
                CONTAINER_NAME="$compose_container"
                return 1
                ;;
        esac
        # Also check if container is just running (no healthcheck defined)
        if docker ps --format '{{.Names}}' | grep -q "^${compose_container}$"; then
            # Running but healthcheck hasn't passed yet — keep waiting
            if [ "$((health_attempts % 5))" -eq 0 ]; then
                log "  Container running, health: ${health} (${health_attempts}/30)"
            fi
        else
            err "  Container stopped unexpectedly. Check: docker logs $compose_container"
            return 1
        fi
    done

    # If we get here, healthcheck didn't pass but container might still be usable
    if docker ps --format '{{.Names}}' | grep -q "^${compose_container}$"; then
        warn "  Healthcheck didn't pass within 90s, but container is running — proceeding"
        CONTAINER_NAME="$compose_container"
        return 0
    fi

    err "  Container failed to start properly."
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
                    # No running container — try to auto-start Docker + container
                    log "  No running OpenClaw container found."
                    log "  Attempting to start Docker and the container automatically..."
                    if ensure_docker_ready; then
                        log "  Container '${CONTAINER_NAME}' is ready"
                    else
                        err "  Could not start Docker container automatically."
                        printf "  %bContainer name (if already running elsewhere):%b " "$BOLD" "$NC"
                        read -r CONTAINER_NAME
                        if [ -z "$CONTAINER_NAME" ]; then err "Required."; continue; fi
                    fi
                fi
                if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                    err "'${CONTAINER_NAME}' is not running."
                    warn "  Trying to start it via ensure_docker_ready..."
                    if ensure_docker_ready; then
                        log "  Container '${CONTAINER_NAME}' started successfully"
                    else
                        err "  Failed. Start Docker Desktop manually and re-run."
                        continue
                    fi
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
# [3.5/7] Install required tools inside the environment
# ============================================================================
install_tools() {
    log "=== [3.5/7] Installing Required Tools ==="

    # Helper: run a command in the right environment
    run_env() {
        if [ "$INSTALL_MODE" = "docker" ]; then
            docker exec -u root "$CONTAINER_NAME" bash -c "$*" 2>/dev/null
        else
            eval "$@" 2>/dev/null
        fi
    }

    run_env_node() {
        if [ "$INSTALL_MODE" = "docker" ]; then
            docker exec -u node "$CONTAINER_NAME" bash -c "$*" 2>/dev/null
        else
            eval "$@" 2>/dev/null
        fi
    }

    # ---- 1. Screenshot tools ----
    log "  [Tools] Installing screenshot tools..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        # Inside Docker: install scrot + xdotool + xclip for X11 screenshots
        docker exec -u root "$CONTAINER_NAME" bash -c '
            apt-get update -qq && apt-get install -y --no-install-recommends \
                scrot xdotool xclip xdg-utils imagemagick 2>/dev/null
            rm -rf /var/lib/apt/lists/*
        ' 2>/dev/null && log "  scrot + xdotool + imagemagick installed" || warn "  Some screenshot tools failed to install"
    else
        # Local mode: check OS-specific screenshot tools
        case "$OS_TYPE" in
            windows)
                # Windows has built-in screenshot via PowerShell (Add-Type + CopyFromScreen)
                # Also check for ShareX or Greenshot CLI
                if command -v nircmd >/dev/null 2>&1; then
                    log "  nircmd available (screenshots)"
                else
                    log "  Windows: using PowerShell for screenshots"
                    log "  (Optional) Install nircmd or ShareX for advanced capture"
                fi
                ;;
            macos)
                # macOS has built-in screencapture
                log "  macOS: screencapture available (built-in)"
                ;;
            linux|wsl)
                if ! command -v scrot >/dev/null 2>&1; then
                    log "  Installing scrot..."
                    sudo apt-get install -y scrot xdotool 2>/dev/null || warn "  Install scrot manually: sudo apt install scrot xdotool"
                else
                    log "  scrot already installed"
                fi
                ;;
        esac
    fi

    # ---- 2. FFmpeg (video/audio processing) ----
    log "  [Tools] Checking FFmpeg..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        if docker exec "$CONTAINER_NAME" bash -c "command -v ffmpeg" >/dev/null 2>&1; then
            local ffver
            ffver=$(docker exec "$CONTAINER_NAME" bash -c "ffmpeg -version 2>&1 | head -1" 2>/dev/null || echo "unknown")
            log "  FFmpeg: $ffver"
        else
            log "  Installing FFmpeg in container..."
            docker exec -u root "$CONTAINER_NAME" bash -c '
                apt-get update -qq && apt-get install -y --no-install-recommends ffmpeg
                rm -rf /var/lib/apt/lists/*
            ' 2>/dev/null && log "  FFmpeg installed" || warn "  FFmpeg install failed"
        fi
    else
        if command -v ffmpeg >/dev/null 2>&1; then
            log "  FFmpeg: $(ffmpeg -version 2>&1 | head -1)"
        else
            warn "  FFmpeg not found — install it for video/audio processing"
            case "$OS_TYPE" in
                windows) warn "  Download from https://ffmpeg.org/download.html or: winget install ffmpeg" ;;
                macos) warn "  Install: brew install ffmpeg" ;;
                linux|wsl) warn "  Install: sudo apt install ffmpeg" ;;
            esac
        fi
    fi

    # ---- 3. Playwright browsers (for lobster plugin) ----
    log "  [Tools] Checking Playwright browsers..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        # Install Playwright + browser deps inside container
        docker exec -u root "$CONTAINER_NAME" bash -c '
            # Install Playwright system dependencies
            apt-get update -qq && apt-get install -y --no-install-recommends \
                libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
                libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
                libpango-1.0-0 libcairo2 libasound2 libxshmfence1 2>/dev/null
            rm -rf /var/lib/apt/lists/*
        ' 2>/dev/null || true

        # Install Playwright Chromium as node user
        docker exec -u node "$CONTAINER_NAME" bash -c '
            npx playwright install chromium 2>/dev/null || true
        ' 2>/dev/null && log "  Playwright Chromium installed in container" || warn "  Playwright install returned non-zero (may still work)"
    else
        if command -v npx >/dev/null 2>&1; then
            log "  Installing Playwright Chromium..."
            npx playwright install chromium 2>/dev/null && log "  Playwright Chromium installed" || warn "  Playwright install failed"
        fi
    fi

    # ---- 4. Screenshot helper script ----
    # Create a portable screenshot script that works cross-platform
    log "  [Tools] Installing screenshot helper script..."
    local screenshot_script=""
    if [ "$INSTALL_MODE" = "docker" ]; then
        screenshot_script="/home/node/.openclaw/workspace/screenshot.sh"
        docker exec -u node "$CONTAINER_NAME" bash -c "cat > $screenshot_script" <<'SCREENSHOT_EOF'
#!/usr/bin/env bash
# Screenshot helper — captures the active window or full screen
# Usage: screenshot.sh [output_path] [--full|--window|--region]
set -euo pipefail
OUTPUT="${1:-/tmp/screenshot_$(date +%Y%m%d_%H%M%S).png}"
MODE="${2:---window}"

case "$MODE" in
    --full)
        if command -v scrot >/dev/null 2>&1; then
            scrot "$OUTPUT"
        elif command -v import >/dev/null 2>&1; then
            import -window root "$OUTPUT"
        else
            echo "No screenshot tool available" >&2; exit 1
        fi
        ;;
    --window)
        if command -v scrot >/dev/null 2>&1; then
            # Get the active window ID
            ACTIVE_WIN=$(xdotool getactivewindow 2>/dev/null || echo "")
            if [ -n "$ACTIVE_WIN" ]; then
                scrot -u "$OUTPUT" || scrot "$OUTPUT"
            else
                scrot "$OUTPUT"
            fi
        elif command -v import >/dev/null 2>&1; then
            ACTIVE_WIN=$(xdotool getactivewindow 2>/dev/null || echo "root")
            import -window "$ACTIVE_WIN" "$OUTPUT"
        else
            echo "No screenshot tool available" >&2; exit 1
        fi
        ;;
    --region)
        if command -v scrot >/dev/null 2>&1; then
            scrot -s "$OUTPUT"
        elif command -v import >/dev/null 2>&1; then
            import "$OUTPUT"
        else
            echo "No screenshot tool available" >&2; exit 1
        fi
        ;;
esac

echo "$OUTPUT"
SCREENSHOT_EOF
        docker exec -u node "$CONTAINER_NAME" bash -c "chmod +x $screenshot_script" 2>/dev/null || true
        log "  screenshot.sh deployed to container workspace"
    else
        local ws="${OPENCLAW_HOME}/workspace"
        mkdir -p "$ws"
        screenshot_script="$ws/screenshot.sh"
        cat > "$screenshot_script" <<'SCREENSHOT_EOF'
#!/usr/bin/env bash
# Screenshot helper — captures the active window or full screen
# Usage: screenshot.sh [output_path] [--full|--window]
set -euo pipefail
OUTPUT="${1:-screenshot_$(date +%Y%m%d_%H%M%S).png}"
MODE="${2:---window}"

OS_TYPE="unknown"
case "$(uname -s 2>/dev/null || echo Unknown)" in
    Linux*)   OS_TYPE="linux" ;;
    Darwin*)  OS_TYPE="macos" ;;
    CYGWIN*|MINGW*|MSYS*) OS_TYPE="windows" ;;
esac

case "$OS_TYPE" in
    windows)
        powershell.exe -NoProfile -Command "
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            \$screen = [System.Windows.Forms.Screen]::PrimaryScreen
            \$bitmap = New-Object System.Drawing.Bitmap(\$screen.Bounds.Width, \$screen.Bounds.Height)
            \$graphics = [System.Drawing.Graphics]::FromImage(\$bitmap)
            \$graphics.CopyFromScreen(\$screen.Bounds.Location, [System.Drawing.Point]::Empty, \$screen.Bounds.Size)
            \$bitmap.Save('$(cygpath -w "$OUTPUT")')
            \$graphics.Dispose()
            \$bitmap.Dispose()
        " 2>/dev/null
        ;;
    macos)
        if [ "$MODE" = "--window" ]; then
            screencapture -w "$OUTPUT"
        else
            screencapture "$OUTPUT"
        fi
        ;;
    linux)
        if command -v scrot >/dev/null 2>&1; then
            if [ "$MODE" = "--window" ]; then
                scrot -u "$OUTPUT" || scrot "$OUTPUT"
            else
                scrot "$OUTPUT"
            fi
        elif command -v import >/dev/null 2>&1; then
            import -window root "$OUTPUT"
        else
            echo "No screenshot tool (install scrot)" >&2; exit 1
        fi
        ;;
esac

echo "$OUTPUT"
SCREENSHOT_EOF
        chmod +x "$screenshot_script" 2>/dev/null || true
        log "  screenshot.sh deployed to $ws/"
    fi

    # ---- 5. Image processing tools (ImageMagick / sharp) ----
    log "  [Tools] Checking image processing tools..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        if docker exec "$CONTAINER_NAME" bash -c "command -v convert" >/dev/null 2>&1; then
            log "  ImageMagick: available"
        else
            docker exec -u root "$CONTAINER_NAME" bash -c '
                apt-get update -qq && apt-get install -y --no-install-recommends imagemagick
                rm -rf /var/lib/apt/lists/*
            ' 2>/dev/null && log "  ImageMagick installed" || warn "  ImageMagick install failed"
        fi
    else
        if command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; then
            log "  ImageMagick: available"
        else
            warn "  ImageMagick not found (optional, for image resizing/conversion)"
        fi
    fi

    # ---- 6. Python packages for media processing ----
    log "  [Tools] Checking Python packages..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        docker exec -u node "$CONTAINER_NAME" bash -c '
            python3 -c "import PIL; import requests" 2>/dev/null && echo "OK" || {
                pip3 install --user --break-system-packages Pillow requests 2>/dev/null || true
            }
        ' 2>/dev/null
        log "  Python packages: Pillow + requests available"
    else
        if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
            log "  Python: available"
        else
            warn "  Python not found (optional, for advanced media processing)"
        fi
    fi

    # ---- 7. curl / wget (for downloading assets) ----
    log "  [Tools] Checking download tools..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        docker exec "$CONTAINER_NAME" bash -c "command -v curl && command -v wget" >/dev/null 2>&1 \
            && log "  curl + wget: available" \
            || {
                docker exec -u root "$CONTAINER_NAME" bash -c '
                    apt-get update -qq && apt-get install -y --no-install-recommends curl wget
                    rm -rf /var/lib/apt/lists/*
                ' 2>/dev/null && log "  curl + wget installed" || warn "  Download tools install failed"
            }
    else
        command -v curl >/dev/null 2>&1 && log "  curl: available" || warn "  curl not found"
    fi

    # ---- 8. jq (JSON processing) ----
    log "  [Tools] Checking jq..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        if docker exec "$CONTAINER_NAME" bash -c "command -v jq" >/dev/null 2>&1; then
            log "  jq: available"
        else
            docker exec -u root "$CONTAINER_NAME" bash -c '
                apt-get update -qq && apt-get install -y --no-install-recommends jq
                rm -rf /var/lib/apt/lists/*
            ' 2>/dev/null && log "  jq installed" || warn "  jq install failed"
        fi
    else
        command -v jq >/dev/null 2>&1 && log "  jq: available" || warn "  jq not found (optional)"
    fi

    # ---- 9. Node.js global tools (used by pipeline) ----
    log "  [Tools] Checking Node.js tools..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        docker exec -u node "$CONTAINER_NAME" bash -c '
            command -v sharp-cli >/dev/null 2>&1 || npm install -g sharp-cli 2>/dev/null || true
        ' 2>/dev/null
        log "  Node.js tools checked"
    fi

    log "  All tools checked"
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
        log "  Restarting container ${CONTAINER_NAME}..."
        docker restart "$CONTAINER_NAME" 2>/dev/null || {
            warn "  docker restart failed — trying ensure_docker_ready..."
            ensure_docker_ready || { err "  Failed to restart container"; return; }
        }
        # Wait for healthcheck
        log "  Waiting for container to be healthy..."
        local restart_attempts=0
        while [ "$restart_attempts" -lt 20 ]; do
            sleep 3
            restart_attempts=$((restart_attempts + 1))
            local health
            health=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
            if [ "$health" = "healthy" ]; then
                log "  Container '${CONTAINER_NAME}' is healthy"
                break
            fi
            if [ "$((restart_attempts % 5))" -eq 0 ]; then
                log "  Waiting... health: ${health} (${restart_attempts}/20)"
            fi
        done
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
    else
        err "  Gateway did not start within 30 seconds"
        err "  Start manually:"
        err "    $OC_BIN gateway --force"
    fi

    # ---- STEP 4: Install and start node host ----
    # The NODE HOST provides tools (browser, exec, camera, screen) to the agent.
    # Without it, the agent has zero tools — only messaging.
    # Docs: https://docs.openclaw.ai/cli/node
    log "  Installing node host (provides browser + exec tools to agent)..."

    # Get gateway port
    local gw_host="127.0.0.1"

    # Stop existing node host
    "$OC_BIN" node stop 2>/dev/null || true
    sleep 1

    # Install as system service with explicit gateway connection
    # --force overwrites existing installation if present
    "$OC_BIN" node install --host "$gw_host" --port "$gw_port" --force 2>/dev/null || {
        warn "  node install failed — trying foreground start"
    }

    # Start/restart the node host service
    "$OC_BIN" node restart 2>/dev/null || {
        # Fallback: run in background with explicit gateway connection
        log "  Starting node host in background..."
        case "$OS_TYPE" in
            windows)
                "$OC_BIN" node run --host "$gw_host" --port "$gw_port" >/dev/null 2>&1 &
                disown "$!" 2>/dev/null || true
                ;;
            *)
                nohup "$OC_BIN" node run --host "$gw_host" --port "$gw_port" >/dev/null 2>&1 &
                disown 2>/dev/null || true
                ;;
        esac
    }

    # ---- STEP 5: Approve the node pairing request ----
    # First connection creates a pending DEVICE pairing request.
    # Must be approved via "openclaw devices approve" (not nodes approve).
    log "  Waiting for node pairing request..."
    sleep 5

    # List pending device requests and auto-approve
    local devices_out
    devices_out=$("$OC_BIN" devices list 2>&1 || true)
    log "  Devices: $devices_out"

    # Try to approve any pending pairing requests
    # Extract request IDs from devices list output
    local request_ids
    request_ids=$(echo "$devices_out" | grep -oE '[a-f0-9-]{8,}' | head -5)
    if [ -n "$request_ids" ]; then
        for rid in $request_ids; do
            log "  Approving device pairing: $rid"
            "$OC_BIN" devices approve "$rid" 2>/dev/null || true
        done
    fi

    # Also try approve --all and other variations
    "$OC_BIN" devices approve --all 2>/dev/null || true
    "$OC_BIN" nodes approve --all 2>/dev/null || true

    # ---- STEP 6: Wait for node to connect ----
    log "  Waiting for node host to connect..."
    local node_attempts=0
    local node_up=false
    while [ "$node_attempts" -lt 10 ]; do
        sleep 3
        node_attempts=$((node_attempts + 1))
        local nodes_out
        nodes_out=$("$OC_BIN" nodes status 2>&1 || true)
        if echo "$nodes_out" | grep -q "Connected: [1-9]"; then
            node_up=true
            break
        fi
        # Check for new pending requests during wait
        local new_pending
        new_pending=$("$OC_BIN" devices list 2>&1 || true)
        local new_rids
        new_rids=$(echo "$new_pending" | grep -oE '[a-f0-9-]{8,}' | head -5)
        for rid in $new_rids; do
            "$OC_BIN" devices approve "$rid" 2>/dev/null || true
        done
    done

    if $node_up; then
        log "  Node host: CONNECTED (agent now has browser + exec tools)"
    else
        warn "  Node host not connected yet"
        warn "  Manual fix:"
        warn "    1. openclaw devices list          (find pending request)"
        warn "    2. openclaw devices approve <id>   (approve it)"
        warn "    3. openclaw nodes status           (verify Connected: 1+)"
    fi

    # ---- Verify browser is accessible ----
    local browser_status
    browser_status=$("$OC_BIN" browser status 2>&1 || true)
    if echo "$browser_status" | grep -qi "enabled: true"; then
        log "  Browser service: ACTIVE"
    else
        warn "  Browser service status unclear — test with: openclaw browser status"
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

            # Node host (provides tools to agent)
            local nodes_status
            nodes_status=$("$OC_BIN" nodes status 2>&1 || true)
            if echo "$nodes_status" | grep -q "Connected: [1-9]"; then
                log "  Node host: CONNECTED (agent has tools)"
            else
                err "  Node host: NOT CONNECTED (agent has NO tools!)"
                err "  Fix:"
                err "    1. openclaw devices list          (find pending request)"
                err "    2. openclaw devices approve <id>   (approve it)"
                err "    3. openclaw nodes status           (verify Connected: 1+)"
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

    # --- TOOLS VERIFICATION ---
    log "  ─── Installed Tools ───"
    if [ "$INSTALL_MODE" = "docker" ]; then
        for tool in ffmpeg scrot xdotool convert curl wget jq python3; do
            if docker exec "$CONTAINER_NAME" bash -c "command -v $tool" >/dev/null 2>&1; then
                log "  $tool: OK"
            else
                warn "  $tool: NOT FOUND"
            fi
        done
        docker exec "$CONTAINER_NAME" bash -c "test -x /home/node/.openclaw/workspace/screenshot.sh" 2>/dev/null \
            && log "  screenshot.sh: OK" || warn "  screenshot.sh: NOT FOUND"
    else
        for tool in ffmpeg curl jq; do
            if command -v "$tool" >/dev/null 2>&1; then
                log "  $tool: OK"
            else
                warn "  $tool: NOT FOUND"
            fi
        done
        if command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; then
            log "  ImageMagick: OK"
        else
            warn "  ImageMagick: NOT FOUND"
        fi
        [ -f "${OPENCLAW_HOME}/workspace/screenshot.sh" ] \
            && log "  screenshot.sh: OK" || warn "  screenshot.sh: NOT FOUND"
    fi
    log "  ─── End Tools ───"

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
    echo -e "  ${GREEN}Tools:${NC}"
    echo "    - screenshot.sh         (active window + full screen capture)"
    echo "    - FFmpeg                (video/audio merging, conversion)"
    echo "    - Playwright Chromium   (headless browser for lobster)"
    echo "    - ImageMagick           (image resize, convert, composite)"
    echo "    - scrot + xdotool       (X11 screenshot + window control)"
    echo "    - curl + wget           (asset download)"
    echo "    - jq                    (JSON processing)"
    echo "    - Python + Pillow       (image processing)"
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
    install_tools
    deploy_credentials
    reindex_memory
    restart_gateway
    verify
    print_summary
}

main "$@"
