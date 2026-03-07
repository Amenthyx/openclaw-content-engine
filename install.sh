#!/usr/bin/env bash
# ============================================================================
# OpenClaw Fully Autonomous Agent — Cross-Platform Installer (bash)
# Works on: Linux, macOS, Windows (Git Bash / WSL / MSYS2 / Cygwin)
# Sets up a fully autonomous agent with browser control, system access,
# account creation, heartbeat scheduler, multi-channel gateway, and more.
# ============================================================================
set -euo pipefail

# --- Colors (safe for all terminals) ---
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

log()  { printf '%b\n' "${GREEN}[OpenClaw]${NC} $*"; }
warn() { printf '%b\n' "${YELLOW}[OpenClaw]${NC} $*"; }
err()  { printf '%b\n' "${RED}[OpenClaw]${NC} $*" >&2; }

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
SOUL_TEMPLATE="${SCRIPT_DIR}/SOUL.md"
OWNER_NAME=""
COMM_STYLE=""
NOTIFY_CHANNEL=""
WORKING_HOURS=""
ENABLE_HEARTBEAT=""
HEARTBEAT_INTERVAL=""
ENABLE_CHANNELS=""
CHANNEL_CONFIGS=""
AUTONOMY_LEVEL="1"

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

    printf '%b\n' "${CYAN}============================================================${NC}"
    printf '%b\n' "${CYAN}  OpenClaw Content Engine Installer${NC}"
    printf '%b\n' "${CYAN}  OS: ${OS_TYPE} | Shell: ${SHELL:-bash}${NC}"
    printf '%b\n' "${CYAN}============================================================${NC}"
    echo ""
    printf '%b\n' "  ${BOLD}Detected:${NC}"
    echo ""

    if $found_local; then
        printf '%b\n' "  ${GREEN}[LOCAL]${NC}   ${local_path}"
    fi
    if $found_docker; then
        printf '%b\n' "  ${GREEN}[DOCKER]${NC}  Containers:"
        echo "$docker_containers" | while read -r name; do
            printf '%b\n' "            - ${name}"
        done
    fi
    if ! $found_local && ! $found_docker; then
        printf '%b\n' "  ${YELLOW}No OpenClaw installation detected.${NC}"
        printf '%b\n' "  ${YELLOW}Install OpenClaw first: https://docs.openclaw.ai${NC}"
    fi

    echo ""
    printf '%b\n' "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    printf '%b\n' "  ${BOLD}Where do you want to install?${NC}"
    echo ""
    printf '%b\n' "  ${BOLD}1)${NC} Local install"
    if $found_local; then
        printf '%b\n' "     -> ${local_path}"
    else
        printf '%b\n' "     -> ~/.openclaw"
    fi
    echo ""
    printf '%b\n' "  ${BOLD}2)${NC} Docker container"
    if $found_docker; then
        printf '%b\n' "     -> $(echo "$docker_containers" | head -1)"
    else
        printf '%b\n' "     -> Specify container name"
    fi
    echo ""
    printf '%b\n' "  ${BOLD}3)${NC} Custom path"
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

    # --- Agent Identity ---
    printf '%b\n' "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    printf '%b\n' "  ${BOLD}Agent Identity${NC}"
    echo ""
    printf '%b\n' "  This installer sets up a fully autonomous agent that can:"
    printf '%b\n' "  - Browse the web, log in, create accounts"
    printf '%b\n' "  - Control your machine (files, apps, clipboard)"
    printf '%b\n' "  - Run scheduled tasks (heartbeat) 24/7"
    printf '%b\n' "  - Communicate across multiple channels"
    printf '%b\n' "  - Create content and publish to social media"
    echo ""
    printf "  %bAgent name%b [OpenClaw]: " "$BOLD" "$NC"
    read -r agent_input
    AGENT_NAME="${agent_input:-OpenClaw}"

    printf "  %bAgent emoji%b [🤖]: " "$BOLD" "$NC"
    read -r emoji_input
    AGENT_EMOJI="${emoji_input:-🤖}"

    printf "  %bYour name (agent's owner)%b []: " "$BOLD" "$NC"
    read -r owner_input
    OWNER_NAME="${owner_input:-}"

    echo ""
    log "Agent: ${AGENT_EMOJI} ${AGENT_NAME}"
    echo ""

    # --- Autonomy Level ---
    printf '%b\n' "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    printf '%b\n' "  ${BOLD}Autonomy Configuration${NC}"
    echo ""
    printf '%b\n' "  How autonomous should the agent be?"
    echo ""
    printf '%b\n' "  ${BOLD}1)${NC} Full autonomy — act on everything, only ask for irreversible actions"
    printf '%b\n' "  ${BOLD}2)${NC} Balanced — act on routine tasks, ask for new/unfamiliar ones"
    printf '%b\n' "  ${BOLD}3)${NC} Conservative — always ask before taking action"
    echo ""
    printf "  %bAutonomy level [1/2/3]%b [1]: " "$BOLD" "$NC"
    read -r autonomy_input
    AUTONOMY_LEVEL="${autonomy_input:-1}"

    # --- Communication style ---
    printf "  %bCommunication style%b [concise/detailed/casual] [concise]: " "$BOLD" "$NC"
    read -r style_input
    COMM_STYLE="${style_input:-concise}"

    # --- Working hours ---
    printf "  %bWorking hours%b [24/7 / business / custom] [24/7]: " "$BOLD" "$NC"
    read -r hours_input
    WORKING_HOURS="${hours_input:-24/7}"

    echo ""

    # --- Heartbeat Scheduler ---
    printf '%b\n' "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    printf '%b\n' "  ${BOLD}Heartbeat Scheduler${NC}"
    echo ""
    printf '%b\n' "  The heartbeat wakes the agent at intervals to run"
    printf '%b\n' "  background tasks (monitoring, scheduled posts, inbox checks)."
    echo ""
    printf "  %bEnable heartbeat?%b [Y/n]: " "$BOLD" "$NC"
    read -r hb_input
    case "${hb_input:-Y}" in
        [nN]*) ENABLE_HEARTBEAT="false" ;;
        *)     ENABLE_HEARTBEAT="true" ;;
    esac

    if [ "$ENABLE_HEARTBEAT" = "true" ]; then
        printf "  %bHeartbeat interval (minutes)%b [15]: " "$BOLD" "$NC"
        read -r hb_interval
        HEARTBEAT_INTERVAL="${hb_interval:-15}"
        log "  Heartbeat: every ${HEARTBEAT_INTERVAL} minutes"
    else
        HEARTBEAT_INTERVAL="0"
        log "  Heartbeat: disabled"
    fi
    echo ""

    # --- Multi-Channel Gateway ---
    printf '%b\n' "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    printf '%b\n' "  ${BOLD}Communication Channels${NC}"
    echo ""
    printf '%b\n' "  Which channels should the agent monitor?"
    printf '%b\n' "  (Configure tokens/keys after install in OpenClaw settings)"
    echo ""

    CHANNEL_CONFIGS=""
    for ch in telegram discord whatsapp slack signal; do
        printf "  %bEnable ${ch}?%b [Y/n]: " "$BOLD" "$NC"
        read -r ch_input
        case "${ch_input:-Y}" in
            [nN]*) ;;
            *)     CHANNEL_CONFIGS="${CHANNEL_CONFIGS} ${ch}" ;;
        esac
    done
    CHANNEL_CONFIGS=$(echo "$CHANNEL_CONFIGS" | xargs)

    echo ""
    if [ -n "$CHANNEL_CONFIGS" ]; then
        log "  Channels: ${CHANNEL_CONFIGS}"
    else
        log "  Channels: none (configure later)"
    fi

    # --- Notification channel ---
    printf "  %bPrimary notification channel%b [telegram]: " "$BOLD" "$NC"
    read -r notify_input
    NOTIFY_CHANNEL="${notify_input:-telegram}"
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
    log "=== [1/10] Installing Knowledge Base ==="

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
    log "=== [2/10] Installing Skill ==="

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
    log "=== [2.5/10] Setting Up Agent: ${AGENT_EMOJI} ${AGENT_NAME} ==="

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
# [2.7/10] Deploy SOUL.md — persistent personality and goals
# ============================================================================
deploy_soul() {
    log "=== [2.7/10] Deploying SOUL.md (Agent Personality & Goals) ==="

    local soul_src="${SCRIPT_DIR}/SOUL.md"
    if [ ! -f "$soul_src" ]; then
        warn "  SOUL.md template not found — skipping"
        return
    fi

    local soul_tmp
    soul_tmp=$(mktemp)

    # Customize SOUL.md with user's answers
    sed \
        -e "s|\[Your name\]|${OWNER_NAME:-Not set}|" \
        -e "s|\[concise/detailed/casual/formal\]|${COMM_STYLE:-concise}|" \
        -e "s|\[24/7 / business hours only / custom schedule\]|${WORKING_HOURS:-24/7}|" \
        -e "s|\[Telegram / Discord / Slack / all\]|${NOTIFY_CHANNEL:-telegram}|" \
        "$soul_src" > "$soul_tmp"

    # Set autonomy level text
    local autonomy_text="Act autonomously on all routine tasks. Only ask for irreversible or high-risk actions."
    case "$AUTONOMY_LEVEL" in
        2) autonomy_text="Act on routine/familiar tasks. Ask before attempting new or unfamiliar operations." ;;
        3) autonomy_text="Always ask before taking any action. Provide recommendations but wait for approval." ;;
    esac
    # Insert autonomy directive after "Operating Mode" line
    # Portable sed -i: macOS requires sed -i '', Linux requires sed -i
    local soul_tmp2
    soul_tmp2=$(mktemp)
    sed "s|24/7 autonomous with human oversight for critical decisions|${autonomy_text}|" "$soul_tmp" > "$soul_tmp2" 2>/dev/null && mv "$soul_tmp2" "$soul_tmp" || rm -f "$soul_tmp2"

    if [ "$INSTALL_MODE" = "local" ]; then
        local ws="${OPENCLAW_HOME}/workspace"
        mkdir -p "$ws"
        if [ -f "$ws/SOUL.md" ]; then
            cp "$ws/SOUL.md" "$ws/SOUL.md.bak"
            log "  Backed up existing SOUL.md"
        fi
        cp "$soul_tmp" "$ws/SOUL.md"
        log "  SOUL.md deployed to $ws/"
    else
        local docker_ws="/home/node/.openclaw/workspace"
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p $docker_ws" 2>/dev/null || true
        docker exec "$CONTAINER_NAME" bash -c "test -f $docker_ws/SOUL.md && cp $docker_ws/SOUL.md $docker_ws/SOUL.md.bak" 2>/dev/null || true
        docker cp "$soul_tmp" "${CONTAINER_NAME}:$docker_ws/SOUL.md"
        docker exec "$CONTAINER_NAME" bash -c "chown node:node $docker_ws/SOUL.md" 2>/dev/null || true
        log "  SOUL.md deployed to container workspace"
    fi

    rm -f "$soul_tmp" 2>/dev/null || true
}

# ============================================================================
# [3/10] Configure OpenClaw for full autonomy
# ============================================================================
configure_openclaw() {
    log "=== [3/10] Configuring OpenClaw for Full Autonomy ==="

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
    log "  [Browser] Setting default profile to 'openclaw' (headless Playwright)..."
    oc_config set browser.defaultProfile openclaw
    oc_cmd browser create-profile --name openclaw --driver openclaw --color "#FF4500" 2>/dev/null || true

    # --- SESSION PERSISTENCE ---
    log "  [Sessions] Enabling cookie/session persistence..."
    oc_config set browser.persistSessions true
    oc_config set browser.cookieStorage file
    oc_config set sessions.autoSave true
    oc_config set sessions.maxAge "30d"

    # --- HEARTBEAT SCHEDULER ---
    if [ "$ENABLE_HEARTBEAT" = "true" ] && [ "$HEARTBEAT_INTERVAL" -gt 0 ] 2>/dev/null; then
        log "  [Heartbeat] Configuring scheduler (every ${HEARTBEAT_INTERVAL}m)..."
        oc_config set heartbeat.enabled true
        oc_config set heartbeat.intervalMinutes "$HEARTBEAT_INTERVAL"
        oc_config set heartbeat.tasks.checkInbox true
        oc_config set heartbeat.tasks.monitorApps true
        oc_config set heartbeat.tasks.scheduledContent true
        oc_config set heartbeat.tasks.healthCheck true
    else
        log "  [Heartbeat] Disabled"
        oc_config set heartbeat.enabled false
    fi

    # --- MULTI-CHANNEL GATEWAY ---
    if [ -n "$CHANNEL_CONFIGS" ]; then
        log "  [Channels] Enabling communication channels..."
        for ch in $CHANNEL_CONFIGS; do
            oc_config set "channels.${ch}.enabled" true
            oc_config set "tools.elevated.allowFrom.${ch}" '["*"]'
            log "    - ${ch}: enabled"
        done
    fi

    # --- NOTIFICATION PREFERENCES ---
    if [ -n "$NOTIFY_CHANNEL" ]; then
        oc_config set notifications.defaultChannel "$NOTIFY_CHANNEL"
        oc_config set notifications.onTaskComplete true
        oc_config set notifications.onError true
        oc_config set notifications.onHeartbeat false
    fi

    # --- AUTONOMOUS AGENT CAPABILITIES ---
    log "  [Autonomy] Enabling full agent capabilities..."
    # File system access
    oc_config set tools.filesystem.enabled true
    oc_config set tools.filesystem.allowWrite true
    # Clipboard access
    oc_config set tools.clipboard.enabled true
    # Process management
    oc_config set tools.process.enabled true
    # Network access
    oc_config set tools.network.enabled true
    # Account/credential management
    oc_config set tools.credentials.autoSave true
    # Memory — long-term retention
    oc_config set memory.longTerm.enabled true
    oc_config set memory.longTerm.autoIndex true
    # Sub-agent spawning for complex tasks
    oc_config set agents.defaults.canSpawn true
    oc_config set agents.defaults.canDelegate true

    # --- VERIFY BROWSER TOOL ---
    log "  [Browser] Verifying browser tool availability..."
    local tools_out
    tools_out=$(oc_cmd tools list 2>/dev/null || true)
    if echo "$tools_out" | grep -qi "browser"; then
        log "  Browser tool: AVAILABLE"
    else
        warn "  Browser tool not visible yet — will be available after gateway restart"
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
cfg.browser.persistSessions = true;
cfg.browser.cookieStorage = 'file';
if (!cfg.sessions) cfg.sessions = {};
cfg.sessions.autoSave = true;
cfg.sessions.maxAge = '30d';
if (!cfg.heartbeat) cfg.heartbeat = {};
cfg.heartbeat.enabled = process.argv[3] === 'true';
cfg.heartbeat.intervalMinutes = parseInt(process.argv[4]) || 15;
cfg.heartbeat.tasks = { checkInbox: true, monitorApps: true, scheduledContent: true, healthCheck: true };
if (!cfg.notifications) cfg.notifications = {};
cfg.notifications.defaultChannel = process.argv[5] || 'telegram';
cfg.notifications.onTaskComplete = true;
cfg.notifications.onError = true;
if (!cfg.memory) cfg.memory = {};
cfg.memory.longTerm = { enabled: true, autoIndex: true };
cfg.agents.defaults.canSpawn = true;
cfg.agents.defaults.canDelegate = true;
fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
" "$config_file" "$ws" "$ENABLE_HEARTBEAT" "$HEARTBEAT_INTERVAL" "$NOTIFY_CHANNEL" 2>&1 && log "  Config written" || err "  Node.js config write failed"

    elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
        local py
        if command -v python3 >/dev/null 2>&1; then py="python3"; else py="python"; fi
        log "  Writing config via Python..."
        "$py" - "$config_file" "$ws" "$ENABLE_HEARTBEAT" "$HEARTBEAT_INTERVAL" "$NOTIFY_CHANNEL" <<'PYEOF'
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
cfg["browser"]["persistSessions"] = True
cfg["browser"]["cookieStorage"] = "file"
cfg.setdefault("sessions", {})
cfg["sessions"]["autoSave"] = True
cfg["sessions"]["maxAge"] = "30d"
cfg.setdefault("heartbeat", {})
cfg["heartbeat"]["enabled"] = sys.argv[3] == "true" if len(sys.argv) > 3 else False
cfg["heartbeat"]["intervalMinutes"] = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 15
cfg["heartbeat"]["tasks"] = {"checkInbox": True, "monitorApps": True, "scheduledContent": True, "healthCheck": True}
cfg.setdefault("notifications", {})
cfg["notifications"]["defaultChannel"] = sys.argv[5] if len(sys.argv) > 5 else "telegram"
cfg["notifications"]["onTaskComplete"] = True
cfg["notifications"]["onError"] = True
cfg.setdefault("memory", {})
cfg["memory"]["longTerm"] = {"enabled": True, "autoIndex": True}
cfg["agents"]["defaults"]["canSpawn"] = True
cfg["agents"]["defaults"]["canDelegate"] = True
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
    log "=== [4/10] Installing Required Tools ==="

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

    # ---- 4.5 TOTP helper script (generates 2FA codes from secrets) ----
    log "  [Tools] Installing TOTP helper script..."
    local totp_content='#!/usr/bin/env bash
# TOTP helper — generates 2FA codes from secrets in credentials.json
# Usage: totp.sh <platform_name>
# Example: totp.sh chatgpt → prints the current TOTP code
set -euo pipefail
PLATFORM="${1:?Usage: totp.sh <platform>}"
CREDS="${HOME}/.openclaw/credentials.json"
if [ ! -f "$CREDS" ]; then echo "credentials.json not found" >&2; exit 1; fi

SECRET=""
if command -v jq >/dev/null 2>&1; then
    SECRET=$(jq -r ".${PLATFORM}.\"2fa_secret\" // empty" "$CREDS" 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
    SECRET=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get(sys.argv[2],{}).get(\"2fa_secret\",\"\"))" "$CREDS" "$PLATFORM" 2>/dev/null)
fi

if [ -z "$SECRET" ]; then echo "No 2FA secret for $PLATFORM" >&2; exit 1; fi

if command -v python3 >/dev/null 2>&1; then
    python3 -c "import pyotp,sys; print(pyotp.TOTP(sys.argv[1]).now())" "$SECRET"
elif command -v python >/dev/null 2>&1; then
    python -c "import pyotp,sys; print(pyotp.TOTP(sys.argv[1]).now())" "$SECRET"
else
    echo "Python with pyotp required for TOTP" >&2; exit 1
fi'

    if [ "$INSTALL_MODE" = "docker" ]; then
        local totp_script="/home/node/.openclaw/workspace/totp.sh"
        echo "$totp_content" | docker exec -i -u node "$CONTAINER_NAME" bash -c "cat > $totp_script" 2>/dev/null
        docker exec -u node "$CONTAINER_NAME" bash -c "chmod +x $totp_script" 2>/dev/null || true
        log "  totp.sh deployed to container workspace"
    else
        local totp_script="${OPENCLAW_HOME}/workspace/totp.sh"
        mkdir -p "$(dirname "$totp_script")"
        echo "$totp_content" > "$totp_script"
        chmod +x "$totp_script" 2>/dev/null || true
        log "  totp.sh deployed to workspace"
    fi

    # ---- 4.6 Password generator script ----
    log "  [Tools] Installing password generator script..."
    local pwgen_content='#!/usr/bin/env bash
# Generate secure random passwords
# Usage: pwgen.sh [length] [--no-special]
LENGTH="${1:-20}"
NO_SPECIAL="${2:-}"
if [ "$NO_SPECIAL" = "--no-special" ]; then
    CHARS="A-Za-z0-9"
else
    CHARS="A-Za-z0-9!@#$%^&*()_+-="
fi
if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -dc "$CHARS" | head -c "$LENGTH"
    echo
elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets,string; chars=string.ascii_letters+string.digits+(\"\" if \"$NO_SPECIAL\" else \"!@#\$%^&*_+-\"); print(\"\".join(secrets.choice(chars) for _ in range(int(\"$LENGTH\"))))"
else
    head -c 100 /dev/urandom | tr -dc "$CHARS" | head -c "$LENGTH"
    echo
fi'

    if [ "$INSTALL_MODE" = "docker" ]; then
        local pwgen_script="/home/node/.openclaw/workspace/pwgen.sh"
        echo "$pwgen_content" | docker exec -i -u node "$CONTAINER_NAME" bash -c "cat > $pwgen_script" 2>/dev/null
        docker exec -u node "$CONTAINER_NAME" bash -c "chmod +x $pwgen_script" 2>/dev/null || true
        log "  pwgen.sh deployed to container workspace"
    else
        local pwgen_script="${OPENCLAW_HOME}/workspace/pwgen.sh"
        echo "$pwgen_content" > "$pwgen_script"
        chmod +x "$pwgen_script" 2>/dev/null || true
        log "  pwgen.sh deployed to workspace"
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

    # ---- 6. Python packages (media + TOTP + email) ----
    log "  [Tools] Checking Python packages..."
    if [ "$INSTALL_MODE" = "docker" ]; then
        docker exec -u node "$CONTAINER_NAME" bash -c '
            python3 -c "import PIL; import requests; import pyotp" 2>/dev/null && echo "OK" || {
                pip3 install --user --break-system-packages Pillow requests pyotp 2>/dev/null || true
            }
        ' 2>/dev/null
        log "  Python packages: Pillow + requests + pyotp available"
    else
        if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
            local py_cmd="python3"
            command -v python3 >/dev/null 2>&1 || py_cmd="python"
            # Install TOTP library for 2FA auto-handling
            "$py_cmd" -c "import pyotp" 2>/dev/null || {
                log "  Installing pyotp (2FA TOTP support)..."
                "$py_cmd" -m pip install --user pyotp 2>/dev/null || warn "  pyotp install failed (optional)"
            }
            log "  Python: available"
        else
            warn "  Python not found (optional, for TOTP 2FA and media processing)"
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
    log "=== [5/10] Setting Up Credentials ==="

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
    log "=== [6/10] Indexing Memory ==="
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
    log "=== [7/10] Full OpenClaw Restart ==="

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

    # ---- STEP 1: Stop all nodes, then kill gateway ----
    log "  Stopping all OpenClaw nodes and gateway..."

    # Stop all connected nodes first (they depend on gateway)
    "$OC_BIN" node stop --all 2>/dev/null || true
    "$OC_BIN" node stop 2>/dev/null || true

    # List all nodes and stop each one individually
    local all_nodes
    all_nodes=$("$OC_BIN" nodes list 2>&1 || true)
    local node_ids
    node_ids=$(echo "$all_nodes" | grep -oE '[a-f0-9-]{8,}' | head -20)
    if [ -n "$node_ids" ]; then
        for nid in $node_ids; do
            log "  Stopping node: $nid"
            "$OC_BIN" node stop "$nid" 2>/dev/null || true
        done
    fi

    # Kill any lingering node host processes
    case "$OS_TYPE" in
        windows)
            wmic.exe process where "CommandLine like '%openclaw%node%run%'" call terminate 2>/dev/null || true
            ;;
        linux|wsl|macos)
            pkill -f "openclaw.*node.*run" 2>/dev/null || true
            ;;
    esac

    sleep 1

    # Now stop the gateway
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
                local _pids
                _pids=$(lsof -ti :"$gw_port" 2>/dev/null || true)
                if [ -n "$_pids" ]; then kill -9 $_pids 2>/dev/null || true; fi
            fi
            # Kill any openclaw gateway process
            pkill -f "openclaw.*gateway" 2>/dev/null || true
            ;;
        macos)
            # Kill by port (lsof on macOS)
            if command -v lsof >/dev/null 2>&1; then
                local _pids
                _pids=$(lsof -ti :"$gw_port" 2>/dev/null || true)
                if [ -n "$_pids" ]; then kill -9 $_pids 2>/dev/null || true; fi
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

    # ---- STEP 4: Restart ALL node hosts ----
    # Node hosts provide tools (browser, exec, camera, screen) to the agent.
    # Without them, the agent has zero tools — only messaging.
    log "  Restarting all node hosts..."

    local gw_host="127.0.0.1"

    # Install/reinstall the local node host
    "$OC_BIN" node install --host "$gw_host" --port "$gw_port" --force 2>/dev/null || {
        warn "  node install failed — will try foreground start"
    }

    # Restart all nodes via CLI
    "$OC_BIN" node restart --all 2>/dev/null || true
    "$OC_BIN" node restart 2>/dev/null || {
        # Fallback: run in background with explicit gateway connection
        log "  Starting local node host in background..."
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

    # ---- STEP 5: Approve all node pairing requests ----
    log "  Approving all node pairing requests..."
    sleep 5

    # Auto-approve all pending devices/nodes
    "$OC_BIN" devices approve --all 2>/dev/null || true
    "$OC_BIN" nodes approve --all 2>/dev/null || true

    # Also approve individual device IDs
    local devices_out
    devices_out=$("$OC_BIN" devices list 2>&1 || true)
    log "  Devices: $devices_out"
    local request_ids
    request_ids=$(echo "$devices_out" | grep -oE '[a-f0-9-]{8,}' | head -10)
    if [ -n "$request_ids" ]; then
        for rid in $request_ids; do
            log "  Approving device: $rid"
            "$OC_BIN" devices approve "$rid" 2>/dev/null || true
        done
    fi

    # ---- STEP 6: Wait for all nodes to reconnect ----
    log "  Waiting for node hosts to reconnect..."
    local node_attempts=0
    local node_up=false
    while [ "$node_attempts" -lt 15 ]; do
        sleep 3
        node_attempts=$((node_attempts + 1))
        local nodes_out
        nodes_out=$("$OC_BIN" nodes status 2>&1 || true)
        if echo "$nodes_out" | grep -q "Connected: [1-9]"; then
            node_up=true
            # Log how many nodes reconnected
            local connected_count
            connected_count=$(echo "$nodes_out" | grep -oE 'Connected: [0-9]+' | grep -oE '[0-9]+' || echo "?")
            log "  Nodes connected: $connected_count"
            break
        fi
        # Keep approving new pairing requests during wait
        local new_pending
        new_pending=$("$OC_BIN" devices list 2>&1 || true)
        local new_rids
        new_rids=$(echo "$new_pending" | grep -oE '[a-f0-9-]{8,}' | head -10)
        for rid in $new_rids; do
            "$OC_BIN" devices approve "$rid" 2>/dev/null || true
        done
        "$OC_BIN" devices approve --all 2>/dev/null || true
        "$OC_BIN" nodes approve --all 2>/dev/null || true
    done

    if $node_up; then
        log "  All node hosts: CONNECTED (agent has full tool access)"
    else
        warn "  Some node hosts may not have reconnected"
        warn "  Manual fix:"
        warn "    1. openclaw nodes status            (check connected nodes)"
        warn "    2. openclaw devices list             (find pending requests)"
        warn "    3. openclaw devices approve --all    (approve all)"
        warn "    4. openclaw node restart --all       (restart all nodes)"
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
    log "=== [8/10] Verifying Installation ==="

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

        # SOUL.md
        if [ -f "${OPENCLAW_HOME}/workspace/SOUL.md" ]; then
            log "  SOUL.md: DEPLOYED"
        else
            warn "  SOUL.md: NOT FOUND"
        fi

        # Heartbeat
        if [ -n "$OC_BIN" ]; then
            local hb_status
            hb_status=$("$OC_BIN" config get heartbeat.enabled 2>/dev/null || echo "?")
            if [ "$hb_status" = "true" ]; then
                local hb_int
                hb_int=$("$OC_BIN" config get heartbeat.intervalMinutes 2>/dev/null || echo "?")
                log "  Heartbeat: ENABLED (every ${hb_int}m)"
            else
                log "  Heartbeat: DISABLED"
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
        docker exec "$CONTAINER_NAME" bash -c "test -x /home/node/.openclaw/workspace/totp.sh" 2>/dev/null \
            && log "  totp.sh: OK" || warn "  totp.sh: NOT FOUND"
        docker exec "$CONTAINER_NAME" bash -c "test -x /home/node/.openclaw/workspace/pwgen.sh" 2>/dev/null \
            && log "  pwgen.sh: OK" || warn "  pwgen.sh: NOT FOUND"
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
        [ -f "${OPENCLAW_HOME}/workspace/totp.sh" ] \
            && log "  totp.sh: OK" || warn "  totp.sh: NOT FOUND"
        [ -f "${OPENCLAW_HOME}/workspace/pwgen.sh" ] \
            && log "  pwgen.sh: OK" || warn "  pwgen.sh: NOT FOUND"
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
    printf '%b\n' "${CYAN}============================================================${NC}"
    printf '%b\n' "${CYAN}  OpenClaw Fully Autonomous Agent — Installation Complete${NC}"
    printf '%b\n' "${CYAN}============================================================${NC}"
    echo ""
    local mode_upper
    mode_upper=$(echo "$INSTALL_MODE" | tr '[:lower:]' '[:upper:]')
    printf '%b\n' "  ${GREEN}Mode:${NC}     ${mode_upper} on ${OS_TYPE}"
    printf '%b\n' "  ${GREEN}Agent:${NC}    ${AGENT_EMOJI} ${AGENT_NAME}"
    if [ -n "$OWNER_NAME" ]; then
        printf '%b\n' "  ${GREEN}Owner:${NC}    ${OWNER_NAME}"
    fi
    if [ -n "$CHANNEL_CONFIGS" ]; then
        printf '%b\n' "  ${GREEN}Channels:${NC} ${CHANNEL_CONFIGS}"
    fi
    if [ "$ENABLE_HEARTBEAT" = "true" ]; then
        printf '%b\n' "  ${GREEN}Heartbeat:${NC} every ${HEARTBEAT_INTERVAL} minutes"
    fi
    echo ""
    printf '%b\n' "  ${GREEN}Installed:${NC}"
    echo "    - Agent identity (IDENTITY.md + SOUL.md)"
    echo "    - 16 knowledge files (content + autonomous ops + system control)"
    echo "    - content-engine skill (SKILL.md)"
    echo "    - credentials.json template (30+ platform slots)"
    echo ""
    printf '%b\n' "  ${GREEN}Tools:${NC}"
    echo "    - screenshot.sh         (desktop/window capture)"
    echo "    - totp.sh               (2FA code generation)"
    echo "    - pwgen.sh              (secure password generation)"
    echo "    - Playwright Chromium   (headless browser)"
    echo "    - FFmpeg                (video/audio processing)"
    echo "    - ImageMagick           (image processing)"
    echo "    - pyotp                 (TOTP 2FA library)"
    echo ""
    printf '%b\n' "  ${GREEN}Capabilities:${NC}"
    echo "    - Browse any website, log in, interact"
    echo "    - Create accounts on new platforms"
    echo "    - Generate 2FA codes automatically"
    echo "    - Control file system, apps, processes"
    echo "    - Run scheduled background tasks"
    echo "    - Multi-channel communication"
    echo "    - Content creation and social publishing"
    echo "    - Session persistence (cookies saved)"
    echo ""
    printf '%b\n' "  ${GREEN}Configured:${NC}"
    echo '    - tools.allow = ["*"]   (full tool access)'
    echo "    - sandbox = off         (browser + filesystem + exec)"
    echo "    - 4 agents / 8 subs    (parallel execution)"
    echo "    - session persistence   (cookies auto-saved)"
    echo "    - long-term memory      (auto-indexed)"
    if [ "$ENABLE_HEARTBEAT" = "true" ]; then
        echo "    - heartbeat scheduler   (every ${HEARTBEAT_INTERVAL}m)"
    fi
    if [ -n "$CHANNEL_CONFIGS" ]; then
        echo "    - channels: ${CHANNEL_CONFIGS}"
    fi
    echo ""
    printf '%b\n' "  ${CYAN}Next Steps:${NC}"
    echo ""
    printf '%b\n' "    ${BOLD}1.${NC} Edit credentials.json with your platform logins"
    if [ "$INSTALL_MODE" = "local" ]; then
        printf '%b\n' "       ${YELLOW}${OPENCLAW_HOME}/credentials.json${NC}"
    else
        printf '%b\n' "       ${YELLOW}docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json${NC}"
    fi
    echo ""
    printf '%b\n' "    ${BOLD}2.${NC} Customize SOUL.md with your goals and preferences"
    if [ "$INSTALL_MODE" = "local" ]; then
        printf '%b\n' "       ${YELLOW}${OPENCLAW_HOME}/workspace/SOUL.md${NC}"
    else
        printf '%b\n' "       ${YELLOW}docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/workspace/SOUL.md${NC}"
    fi
    echo ""
    printf '%b\n' "    ${BOLD}3.${NC} Configure channel tokens (Telegram bot token, Discord token, etc.)"
    printf '%b\n' "       ${YELLOW}openclaw config set channels.telegram.token YOUR_TOKEN${NC}"
    echo ""
    printf '%b\n' "    ${BOLD}4.${NC} Test the agent:"
    echo '       "Open the browser and go to google.com"'
    echo '       "Create a new GitHub account"'
    echo '       "Take a screenshot of the desktop"'
    echo '       "What files are on my Desktop?"'
    echo ""
    printf '%b\n' "${CYAN}============================================================${NC}"
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
    deploy_soul
    configure_openclaw
    install_tools
    deploy_credentials
    reindex_memory
    restart_gateway
    verify
    print_summary
}

main "$@"
