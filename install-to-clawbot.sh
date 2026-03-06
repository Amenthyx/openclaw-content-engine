#!/usr/bin/env bash
# ============================================================================
# Content Engine — ClawBot Installation Script
# Installs the Content Engine knowledge base + skill into a running ClawBot
# Browser-first approach — no API keys, only login credentials
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[Content-Engine]${NC} $*"; }
warn() { echo -e "${YELLOW}[Content-Engine]${NC} $*"; }
err()  { echo -e "${RED}[Content-Engine]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_DIR="${SCRIPT_DIR}/knowledge"
SKILL_DIR="${SCRIPT_DIR}/skills/content-engine"
CREDS_TEMPLATE="${SCRIPT_DIR}/credentials-template.json"
CONTAINER_NAME="${CLAWBOT_CONTAINER:-clawbot}"

# ============================================================================
# Pre-flight checks
# ============================================================================
preflight() {
    log "Running pre-flight checks..."

    if [ ! -d "$KNOWLEDGE_DIR" ] || [ -z "$(ls -A "$KNOWLEDGE_DIR"/*.md 2>/dev/null)" ]; then
        err "Knowledge directory not found or empty: $KNOWLEDGE_DIR"
        exit 1
    fi

    if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
        err "Skill not found: $SKILL_DIR/SKILL.md"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        err "Docker not found. Install Docker first."
        exit 1
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        err "Container '${CONTAINER_NAME}' is not running."
        err "Start it with: docker compose up -d (in the OpenClaw-Docker directory)"
        exit 1
    fi

    local file_count=$(ls -1 "$KNOWLEDGE_DIR"/*.md 2>/dev/null | wc -l)
    log "Found ${file_count} knowledge files"
    log "Target container: ${CONTAINER_NAME}"
    echo ""
}

# ============================================================================
# Install knowledge base
# ============================================================================
install_knowledge() {
    log "=== Installing Knowledge Base ==="

    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/memory/content-engine && chown -R node:node /home/node/.openclaw/memory"

    for f in "$KNOWLEDGE_DIR"/*.md; do
        local filename=$(basename "$f")
        docker cp "$f" "${CONTAINER_NAME}:/home/node/.openclaw/memory/content-engine/${filename}"
        log "  ${filename}"
    done

    docker exec "$CONTAINER_NAME" bash -c \
        "chown -R node:node /home/node/.openclaw/memory/content-engine"

    local count=$(ls -1 "$KNOWLEDGE_DIR"/*.md | wc -l)
    log "  ${count} knowledge files installed"
}

# ============================================================================
# Install skill
# ============================================================================
install_skill() {
    log "=== Installing Content Engine Skill ==="

    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/skills/content-engine && chown -R node:node /home/node/.openclaw/skills"

    docker cp "$SKILL_DIR/SKILL.md" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/SKILL.md"

    if [ -d "$SKILL_DIR/scripts" ]; then
        docker cp "$SKILL_DIR/scripts" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/"
    fi

    docker exec "$CONTAINER_NAME" bash -c \
        "chown -R node:node /home/node/.openclaw/skills/content-engine"

    log "  Skill installed"
}

# ============================================================================
# Install agent instructions
# ============================================================================
install_agent_config() {
    log "=== Configuring Agent Instructions ==="

    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/agents/main && chown -R node:node /home/node/.openclaw/agents"

    docker exec "$CONTAINER_NAME" bash -c 'cat > /home/node/.openclaw/agents/main/system-prompt-content-engine.md << '\''SYSPROMPT'\''
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
- If CAPTCHA appears: pause, notify user, wait for VNC solve
- If login fails: retry once, then notify user
- Download generated content immediately (URLs may expire)
- Use FFmpeg locally for all video/audio processing
SYSPROMPT'

    docker exec "$CONTAINER_NAME" bash -c \
        "chown node:node /home/node/.openclaw/agents/main/system-prompt-content-engine.md"

    log "  Agent instructions installed"
}

# ============================================================================
# Deploy credentials template
# ============================================================================
deploy_credentials() {
    log "=== Setting Up Credentials ==="

    # Check if credentials already exist
    if docker exec "$CONTAINER_NAME" bash -c "test -f /home/node/.openclaw/credentials.json" 2>/dev/null; then
        log "  credentials.json already exists — skipping (won't overwrite)"
    else
        docker cp "$CREDS_TEMPLATE" "${CONTAINER_NAME}:/home/node/.openclaw/credentials.json"
        docker exec "$CONTAINER_NAME" bash -c \
            "chown node:node /home/node/.openclaw/credentials.json && chmod 600 /home/node/.openclaw/credentials.json"
        warn "  credentials.json deployed — EDIT IT with your login details:"
        warn "  docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json"
    fi

    # Create sessions directory
    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/sessions && chown node:node /home/node/.openclaw/sessions"
    log "  Sessions directory ready"

    # Create workspace directory
    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/workspace && chown node:node /home/node/.openclaw/workspace"
    log "  Workspace directory ready"
}

# ============================================================================
# Trigger memory reindex
# ============================================================================
reindex_memory() {
    log "=== Triggering Memory Reindex ==="

    docker exec -u node "$CONTAINER_NAME" bash -c \
        "openclaw memory index --force 2>&1" || {
        warn "Auto-reindex not available. Memory will be indexed on next query."
    }

    log "  Memory reindex triggered"
}

# ============================================================================
# Verify installation
# ============================================================================
verify() {
    log "=== Verifying Installation ==="

    local kb_count=$(docker exec "$CONTAINER_NAME" bash -c \
        "ls -1 /home/node/.openclaw/memory/content-engine/*.md 2>/dev/null | wc -l")
    [ "$kb_count" -gt 0 ] && log "  Knowledge base: ${kb_count} files" || err "  Knowledge base: NOT FOUND"

    docker exec "$CONTAINER_NAME" bash -c \
        "test -f /home/node/.openclaw/skills/content-engine/SKILL.md" 2>/dev/null \
        && log "  Skill: INSTALLED" || err "  Skill: NOT FOUND"

    docker exec "$CONTAINER_NAME" bash -c \
        "test -f /home/node/.openclaw/agents/main/system-prompt-content-engine.md" 2>/dev/null \
        && log "  Agent config: INSTALLED" || err "  Agent config: NOT FOUND"

    docker exec "$CONTAINER_NAME" bash -c \
        "test -f /home/node/.openclaw/credentials.json" 2>/dev/null \
        && log "  Credentials: PRESENT" || warn "  Credentials: NOT CONFIGURED"

    docker exec "$CONTAINER_NAME" bash -c \
        "test -d /home/node/.openclaw/sessions" 2>/dev/null \
        && log "  Sessions dir: READY" || warn "  Sessions dir: MISSING"
}

# ============================================================================
# Print summary
# ============================================================================
print_summary() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  Content Engine — Installation Complete${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${GREEN}Mode:${NC}            Browser automation (no API keys)"
    echo -e "  ${GREEN}Knowledge Base:${NC}  13 files installed to memory"
    echo -e "  ${GREEN}Skill:${NC}           content-engine"
    echo -e "  ${GREEN}Credentials:${NC}     /home/node/.openclaw/credentials.json"
    echo -e "  ${GREEN}Sessions:${NC}        /home/node/.openclaw/sessions/"
    echo -e "  ${GREEN}Workspace:${NC}       /home/node/.openclaw/workspace/"
    echo ""
    echo -e "  ${CYAN}Next Steps:${NC}"
    echo -e "    1. Edit credentials with your platform logins:"
    echo -e "       ${YELLOW}docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json${NC}"
    echo ""
    echo -e "    2. Watch ClawBot work via noVNC:"
    echo -e "       ${YELLOW}http://localhost:6080${NC}"
    echo ""
    echo -e "    3. Send ClawBot a content request:"
    echo -e "       \"Create a 30-second promo video for my coffee brand\""
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================
main() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  Content Engine — ClawBot Installer (Browser Mode)${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""

    preflight
    install_knowledge
    install_skill
    install_agent_config
    deploy_credentials
    reindex_memory
    verify
    print_summary
}

main "$@"
