#!/usr/bin/env bash
# ============================================================================
# Content Engine — Interactive Installer
# Supports: Local install, Docker container, Custom path
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[Content-Engine]${NC} $*"; }
warn() { echo -e "${YELLOW}[Content-Engine]${NC} $*"; }
err()  { echo -e "${RED}[Content-Engine]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_DIR="${SCRIPT_DIR}/knowledge"
SKILL_DIR="${SCRIPT_DIR}/skills/content-engine"
CREDS_TEMPLATE="${SCRIPT_DIR}/credentials-template.json"

# Detected paths
INSTALL_MODE=""
OPENCLAW_HOME=""
CONTAINER_NAME=""

# ============================================================================
# Detect existing installations
# ============================================================================
detect_installations() {
    echo ""
    log "Scanning for OpenClaw installations..."
    echo ""

    local found_local=false
    local found_docker=false
    local local_path=""
    local docker_containers=""

    # Check common local paths
    for candidate in \
        "$HOME/.openclaw" \
        "/home/node/.openclaw" \
        "C:/Users/Software Engineering/.openclaw" \
        "${USERPROFILE:-}/.openclaw" \
        "${APPDATA:-}/openclaw"; do
        if [ -d "$candidate" ] 2>/dev/null; then
            local_path="$candidate"
            found_local=true
            break
        fi
    done

    # Check if openclaw binary exists
    local openclaw_bin=""
    if command -v openclaw &>/dev/null; then
        openclaw_bin=$(command -v openclaw)
    fi

    # Check Docker containers
    if command -v docker &>/dev/null; then
        docker_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i "claw" || true)
        if [ -n "$docker_containers" ]; then
            found_docker=true
        fi
    fi

    # Display findings
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  OpenClaw Content Engine — Installer${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${BOLD}Detected Installations:${NC}"
    echo ""

    if $found_local; then
        echo -e "  ${GREEN}[LOCAL]${NC}   Config found at: ${BOLD}${local_path}${NC}"
        if [ -n "$openclaw_bin" ]; then
            echo -e "            Binary: ${openclaw_bin}"
        fi
    fi

    if $found_docker; then
        echo -e "  ${GREEN}[DOCKER]${NC}  Running containers:"
        echo "$docker_containers" | while read -r name; do
            echo -e "            - ${BOLD}${name}${NC}"
        done
    fi

    if ! $found_local && ! $found_docker; then
        echo -e "  ${YELLOW}No installations detected automatically.${NC}"
    fi

    echo ""
    echo -e "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    echo -e "  ${BOLD}Where do you want to install the Content Engine?${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Local install"
    if $found_local; then
        echo -e "     → ${local_path}"
    else
        echo -e "     → ~/.openclaw (default)"
    fi
    echo ""
    echo -e "  ${BOLD}2)${NC} Docker container"
    if $found_docker; then
        echo -e "     → Container: $(echo "$docker_containers" | head -1)"
    else
        echo -e "     → Specify container name"
    fi
    echo ""
    echo -e "  ${BOLD}3)${NC} Custom path"
    echo -e "     → Specify your OpenClaw config directory"
    echo ""

    # Read choice
    while true; do
        echo -ne "  ${BOLD}Choose [1/2/3]:${NC} "
        read -r choice
        case "$choice" in
            1)
                INSTALL_MODE="local"
                if $found_local; then
                    OPENCLAW_HOME="$local_path"
                else
                    OPENCLAW_HOME="$HOME/.openclaw"
                fi
                break
                ;;
            2)
                INSTALL_MODE="docker"
                if $found_docker; then
                    CONTAINER_NAME=$(echo "$docker_containers" | head -1)
                    echo -ne "  Container name [${CONTAINER_NAME}]: "
                    read -r custom_name
                    [ -n "$custom_name" ] && CONTAINER_NAME="$custom_name"
                else
                    echo -ne "  Container name: "
                    read -r CONTAINER_NAME
                    if [ -z "$CONTAINER_NAME" ]; then
                        err "Container name required."
                        continue
                    fi
                fi
                # Verify container is running
                if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                    err "Container '${CONTAINER_NAME}' is not running."
                    continue
                fi
                break
                ;;
            3)
                echo -ne "  OpenClaw config path: "
                read -r custom_path
                if [ -z "$custom_path" ]; then
                    err "Path required."
                    continue
                fi
                INSTALL_MODE="local"
                OPENCLAW_HOME="$custom_path"
                break
                ;;
            *)
                warn "Please enter 1, 2, or 3."
                ;;
        esac
    done

    echo ""
    if [ "$INSTALL_MODE" = "local" ]; then
        log "Install mode: LOCAL → ${OPENCLAW_HOME}"
    else
        log "Install mode: DOCKER → container '${CONTAINER_NAME}'"
    fi
    echo ""
}

# ============================================================================
# Local install functions
# ============================================================================
install_knowledge_local() {
    log "=== Installing Knowledge Base ==="
    mkdir -p "${OPENCLAW_HOME}/memory/content-engine"

    for f in "$KNOWLEDGE_DIR"/*.md; do
        local filename=$(basename "$f")
        cp "$f" "${OPENCLAW_HOME}/memory/content-engine/${filename}"
        log "  ${filename}"
    done

    local count=$(ls -1 "$KNOWLEDGE_DIR"/*.md | wc -l)
    log "  ${count} knowledge files installed"
}

install_skill_local() {
    log "=== Installing Content Engine Skill ==="
    mkdir -p "${OPENCLAW_HOME}/skills/content-engine"
    cp "$SKILL_DIR/SKILL.md" "${OPENCLAW_HOME}/skills/content-engine/SKILL.md"

    if [ -d "$SKILL_DIR/scripts" ]; then
        cp -r "$SKILL_DIR/scripts" "${OPENCLAW_HOME}/skills/content-engine/"
    fi

    log "  Skill installed"
}

install_agent_local() {
    log "=== Configuring Agent Instructions ==="
    mkdir -p "${OPENCLAW_HOME}/agents/main"

    cat > "${OPENCLAW_HOME}/agents/main/system-prompt-content-engine.md" << 'SYSPROMPT'
# Content Engine Agent Instructions

You are a fully autonomous content creation agent that operates through BROWSER AUTOMATION.
You log into platforms using email/password credentials — you NEVER use API keys.

## How You Operate

1. Load credentials from ~/.openclaw/credentials.json (or the configured path)
2. Open browser (Chromium/Chrome)
3. Login to the needed platform using stored email/password
4. Perform actions through the browser UI (generate, download, upload, publish)
5. Use FFmpeg locally for video/audio processing (no browser needed)
6. Save all generated assets to ~/.openclaw/workspace/

## Your Knowledge Base

Search your memory for relevant knowledge before any content task:
- 01-platform-authentication.md — Browser login flows for every platform
- 02-image-generation.md — Image creation workflows
- 03-video-generation.md — Video generation + FFmpeg commands
- 04-audio-music.md — Voiceover and music generation
- 05-content-strategy.md — Content planning and platform optimization
- 06-workflow-orchestration.md — Pipeline templates and error recovery
- 07-prompt-engineering.md — Prompt patterns per platform
- 08-asset-management.md — File organization
- 09-analytics-optimization.md — Performance tracking
- 10-safety-compliance.md — Content policies and legal
- 11-browser-automation.md — Browser patterns, human-like behavior, CAPTCHA handling
- 12-api-endpoints-reference.md — Platform URLs and browser workflows

## Key Rules

- ALWAYS use browser — never API keys
- Save cookies after login for session persistence
- Act human-like: random delays, natural typing, realistic mouse movements
- If CAPTCHA appears: pause, notify user, wait for solve
- If login fails: retry once, then notify user
- Download generated content immediately (URLs may expire)
- Use FFmpeg locally for all video/audio processing
SYSPROMPT

    log "  Agent instructions installed"
}

deploy_credentials_local() {
    log "=== Setting Up Credentials ==="

    if [ -f "${OPENCLAW_HOME}/credentials.json" ]; then
        log "  credentials.json already exists — skipping (won't overwrite)"
    else
        cp "$CREDS_TEMPLATE" "${OPENCLAW_HOME}/credentials.json"
        chmod 600 "${OPENCLAW_HOME}/credentials.json" 2>/dev/null || true
        warn "  credentials.json created — EDIT IT with your login details:"
        warn "  ${OPENCLAW_HOME}/credentials.json"
    fi

    mkdir -p "${OPENCLAW_HOME}/sessions"
    mkdir -p "${OPENCLAW_HOME}/workspace"
    log "  Sessions and workspace directories ready"
}

reindex_local() {
    log "=== Triggering Memory Reindex ==="
    if command -v openclaw &>/dev/null; then
        openclaw memory sync --force 2>&1 || warn "Auto-reindex not available. Will index on next query."
    else
        warn "openclaw CLI not in PATH. Memory will be indexed on next startup."
    fi
}

# ============================================================================
# Docker install functions
# ============================================================================
install_knowledge_docker() {
    log "=== Installing Knowledge Base ==="
    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/memory/content-engine"

    for f in "$KNOWLEDGE_DIR"/*.md; do
        local filename=$(basename "$f")
        docker cp "$f" "${CONTAINER_NAME}:/home/node/.openclaw/memory/content-engine/${filename}"
        log "  ${filename}"
    done

    docker exec "$CONTAINER_NAME" bash -c \
        "chown -R node:node /home/node/.openclaw/memory/content-engine" 2>/dev/null || true

    local count=$(ls -1 "$KNOWLEDGE_DIR"/*.md | wc -l)
    log "  ${count} knowledge files installed"
}

install_skill_docker() {
    log "=== Installing Content Engine Skill ==="
    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/skills/content-engine"

    docker cp "$SKILL_DIR/SKILL.md" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/SKILL.md"

    if [ -d "$SKILL_DIR/scripts" ]; then
        docker cp "$SKILL_DIR/scripts" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/"
    fi

    docker exec "$CONTAINER_NAME" bash -c \
        "chown -R node:node /home/node/.openclaw/skills/content-engine" 2>/dev/null || true

    log "  Skill installed"
}

install_agent_docker() {
    log "=== Configuring Agent Instructions ==="
    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/agents/main"

    # Copy agent prompt via temp file
    local tmpfile=$(mktemp)
    cat > "$tmpfile" << 'SYSPROMPT'
# Content Engine Agent Instructions

You are a fully autonomous content creation agent that operates through BROWSER AUTOMATION.
You log into platforms using email/password credentials — you NEVER use API keys.

## How You Operate

1. Load credentials from /home/node/.openclaw/credentials.json
2. Open Chromium browser (visible on VNC at http://localhost:6080)
3. Login to the needed platform using stored email/password
4. Perform actions through the browser UI (generate, download, upload, publish)
5. Use FFmpeg locally for video/audio processing (no browser needed)
6. Save all generated assets to /home/node/.openclaw/workspace/

## Your Knowledge Base

Search your memory for relevant knowledge before any content task.

## Key Rules

- ALWAYS use browser — never API keys
- Save cookies after login for session persistence
- Act human-like: random delays, natural typing, realistic mouse movements
- If CAPTCHA appears: pause, notify user, wait for VNC solve at http://localhost:6080
- If login fails: retry once, then notify user
- Download generated content immediately (URLs may expire)
- Use FFmpeg locally for all video/audio processing
SYSPROMPT

    docker cp "$tmpfile" "${CONTAINER_NAME}:/home/node/.openclaw/agents/main/system-prompt-content-engine.md"
    rm -f "$tmpfile"

    docker exec "$CONTAINER_NAME" bash -c \
        "chown node:node /home/node/.openclaw/agents/main/system-prompt-content-engine.md" 2>/dev/null || true

    log "  Agent instructions installed"
}

deploy_credentials_docker() {
    log "=== Setting Up Credentials ==="

    if docker exec "$CONTAINER_NAME" bash -c "test -f /home/node/.openclaw/credentials.json" 2>/dev/null; then
        log "  credentials.json already exists — skipping (won't overwrite)"
    else
        docker cp "$CREDS_TEMPLATE" "${CONTAINER_NAME}:/home/node/.openclaw/credentials.json"
        docker exec "$CONTAINER_NAME" bash -c \
            "chown node:node /home/node/.openclaw/credentials.json && chmod 600 /home/node/.openclaw/credentials.json" 2>/dev/null || true
        warn "  credentials.json deployed — EDIT IT:"
        warn "  docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json"
    fi

    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/sessions /home/node/.openclaw/workspace" 2>/dev/null || true

    log "  Sessions and workspace directories ready"
}

reindex_docker() {
    log "=== Triggering Memory Reindex ==="
    docker exec -u node "$CONTAINER_NAME" bash -c \
        "openclaw memory sync --force 2>&1" 2>/dev/null || {
        warn "Auto-reindex not available. Memory will be indexed on next query."
    }
}

# ============================================================================
# Verify
# ============================================================================
verify_installation() {
    log "=== Verifying Installation ==="

    if [ "$INSTALL_MODE" = "local" ]; then
        [ -d "${OPENCLAW_HOME}/memory/content-engine" ] \
            && log "  Knowledge base: $(ls -1 "${OPENCLAW_HOME}/memory/content-engine/"*.md 2>/dev/null | wc -l) files" \
            || err "  Knowledge base: NOT FOUND"

        [ -f "${OPENCLAW_HOME}/skills/content-engine/SKILL.md" ] \
            && log "  Skill: INSTALLED" || err "  Skill: NOT FOUND"

        [ -f "${OPENCLAW_HOME}/agents/main/system-prompt-content-engine.md" ] \
            && log "  Agent config: INSTALLED" || err "  Agent config: NOT FOUND"

        [ -f "${OPENCLAW_HOME}/credentials.json" ] \
            && log "  Credentials: PRESENT" || warn "  Credentials: NOT CONFIGURED"
    else
        local kb_count=$(docker exec "$CONTAINER_NAME" bash -c \
            "ls -1 /home/node/.openclaw/memory/content-engine/*.md 2>/dev/null | wc -l")
        [ "$kb_count" -gt 0 ] && log "  Knowledge base: ${kb_count} files" || err "  Knowledge base: NOT FOUND"

        docker exec "$CONTAINER_NAME" bash -c \
            "test -f /home/node/.openclaw/skills/content-engine/SKILL.md" 2>/dev/null \
            && log "  Skill: INSTALLED" || err "  Skill: NOT FOUND"

        docker exec "$CONTAINER_NAME" bash -c \
            "test -f /home/node/.openclaw/credentials.json" 2>/dev/null \
            && log "  Credentials: PRESENT" || warn "  Credentials: NOT CONFIGURED"
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
    echo -e "  ${GREEN}Mode:${NC}            ${INSTALL_MODE^^} (browser automation, no API keys)"

    if [ "$INSTALL_MODE" = "local" ]; then
        echo -e "  ${GREEN}Config dir:${NC}      ${OPENCLAW_HOME}"
        echo -e "  ${GREEN}Knowledge:${NC}       ${OPENCLAW_HOME}/memory/content-engine/"
        echo -e "  ${GREEN}Skill:${NC}           ${OPENCLAW_HOME}/skills/content-engine/"
        echo -e "  ${GREEN}Credentials:${NC}     ${OPENCLAW_HOME}/credentials.json"
        echo -e "  ${GREEN}Sessions:${NC}        ${OPENCLAW_HOME}/sessions/"
        echo -e "  ${GREEN}Workspace:${NC}       ${OPENCLAW_HOME}/workspace/"
        echo ""
        echo -e "  ${CYAN}Next Steps:${NC}"
        echo -e "    1. Edit credentials with your platform logins:"
        echo -e "       ${YELLOW}nano ${OPENCLAW_HOME}/credentials.json${NC}"
    else
        echo -e "  ${GREEN}Container:${NC}       ${CONTAINER_NAME}"
        echo -e "  ${GREEN}Knowledge:${NC}       /home/node/.openclaw/memory/content-engine/"
        echo -e "  ${GREEN}Credentials:${NC}     /home/node/.openclaw/credentials.json"
        echo ""
        echo -e "  ${CYAN}Next Steps:${NC}"
        echo -e "    1. Edit credentials with your platform logins:"
        echo -e "       ${YELLOW}docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json${NC}"
        echo ""
        echo -e "    2. Watch ClawBot work via noVNC:"
        echo -e "       ${YELLOW}http://localhost:6080${NC}"
    fi

    echo ""
    echo -e "    2. Send ClawBot a content request:"
    echo -e "       \"Create a 30-second promo video for my coffee brand\""
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================
main() {
    # Pre-flight: check knowledge files exist
    if [ ! -d "$KNOWLEDGE_DIR" ] || [ -z "$(ls -A "$KNOWLEDGE_DIR"/*.md 2>/dev/null)" ]; then
        err "Knowledge directory not found: $KNOWLEDGE_DIR"
        err "Run this script from the openclaw-content-engine directory."
        exit 1
    fi

    detect_installations

    if [ "$INSTALL_MODE" = "local" ]; then
        install_knowledge_local
        install_skill_local
        install_agent_local
        deploy_credentials_local
        reindex_local
    else
        install_knowledge_docker
        install_skill_docker
        install_agent_docker
        deploy_credentials_docker
        reindex_docker
    fi

    verify_installation
    print_summary
}

main "$@"
