#!/usr/bin/env bash
# ============================================================================
# Content Engine — ClawBot Installation Script
# Installs the Content Engine knowledge base + skill into a running ClawBot
# ============================================================================
set -euo pipefail

# Colors
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
CONTAINER_NAME="${CLAWBOT_CONTAINER:-clawbot}"

# ============================================================================
# Pre-flight checks
# ============================================================================
preflight() {
    log "Running pre-flight checks..."

    # Check knowledge files exist
    if [ ! -d "$KNOWLEDGE_DIR" ] || [ -z "$(ls -A "$KNOWLEDGE_DIR"/*.md 2>/dev/null)" ]; then
        err "Knowledge directory not found or empty: $KNOWLEDGE_DIR"
        err "Run this script from the openclaw-content-engine directory."
        exit 1
    fi

    # Check skill exists
    if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
        err "Skill not found: $SKILL_DIR/SKILL.md"
        exit 1
    fi

    # Check Docker is available
    if ! command -v docker &> /dev/null; then
        err "Docker not found. Install Docker first."
        exit 1
    fi

    # Check container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        err "Container '${CONTAINER_NAME}' is not running."
        err "Start it with: docker compose up -d (in the OpenClaw-Docker directory)"
        exit 1
    fi

    local file_count=$(ls -1 "$KNOWLEDGE_DIR"/*.md 2>/dev/null | wc -l)
    local total_size=$(du -sh "$KNOWLEDGE_DIR" 2>/dev/null | cut -f1)
    log "Found ${file_count} knowledge files (${total_size})"
    log "Target container: ${CONTAINER_NAME}"
    echo ""
}

# ============================================================================
# Install knowledge base into ClawBot memory
# ============================================================================
install_knowledge() {
    log "=== Installing Knowledge Base ==="

    # Create memory directory inside container
    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/memory/content-engine && chown -R node:node /home/node/.openclaw/memory"

    # Copy each knowledge file
    for f in "$KNOWLEDGE_DIR"/*.md; do
        local filename=$(basename "$f")
        docker cp "$f" "${CONTAINER_NAME}:/home/node/.openclaw/memory/content-engine/${filename}"
        log "  Copied: ${filename}"
    done

    # Fix ownership
    docker exec "$CONTAINER_NAME" bash -c \
        "chown -R node:node /home/node/.openclaw/memory/content-engine"

    local count=$(ls -1 "$KNOWLEDGE_DIR"/*.md | wc -l)
    log "  ${count} knowledge files installed"
}

# ============================================================================
# Install Content Engine skill
# ============================================================================
install_skill() {
    log "=== Installing Content Engine Skill ==="

    # Create skill directory inside container
    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/skills/content-engine && chown -R node:node /home/node/.openclaw/skills"

    # Copy SKILL.md
    docker cp "$SKILL_DIR/SKILL.md" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/SKILL.md"
    log "  Copied: SKILL.md"

    # Copy scripts if they exist
    if [ -d "$SKILL_DIR/scripts" ]; then
        docker cp "$SKILL_DIR/scripts" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/"
        log "  Copied: scripts/"
    fi

    # Fix ownership
    docker exec "$CONTAINER_NAME" bash -c \
        "chown -R node:node /home/node/.openclaw/skills/content-engine"

    log "  Skill installed"
}

# ============================================================================
# Install system prompt / agent instructions
# ============================================================================
install_agent_config() {
    log "=== Configuring Agent Instructions ==="

    # Create agents directory
    docker exec "$CONTAINER_NAME" bash -c \
        "mkdir -p /home/node/.openclaw/agents/main && chown -R node:node /home/node/.openclaw/agents"

    # Create the agent system prompt that references the knowledge base
    docker exec "$CONTAINER_NAME" bash -c 'cat > /home/node/.openclaw/agents/main/system-prompt-content-engine.md << '\''SYSPROMPT'\''
# Content Engine Agent Instructions

You have access to a comprehensive Content Engine knowledge base stored in your memory.
When handling ANY content creation, media generation, or social media task, search your
memory for relevant knowledge before proceeding.

## How to Use Your Knowledge Base

Your memory contains 13 knowledge files covering:
- Platform authentication (API keys, OAuth, session management)
- Image generation (DALL-E, Midjourney, Stable Diffusion, prompt engineering)
- Video generation (Higgsfield, Runway, FFmpeg commands)
- Audio and music (ElevenLabs, Suno AI, OpenAI TTS)
- Content strategy (calendars, platform specs, scripts, hashtags)
- Workflow orchestration (pipelines, error recovery, cost estimation)
- Prompt engineering (per-platform prompt patterns, templates)
- Asset management (file organization, cloud storage, versioning)
- Analytics and optimization (KPIs, reporting, trend detection)
- Safety and compliance (content policies, copyright, accessibility)
- Browser automation (login flows, session management)
- API endpoints reference (exact URLs, payloads, rate limits, costs)

## When You Receive a Content Request

1. Search memory for relevant knowledge: `memory search "topic"`
2. Identify the right pipeline from 06-workflow-orchestration.md
3. Follow the pipeline steps, using API references from 12-api-endpoints-reference.md
4. Apply platform-specific optimization from 05-content-strategy.md
5. Run safety checks from 10-safety-compliance.md before publishing
6. Report results with cost breakdown

## Available Tools

You can execute content creation by:
- Making HTTP requests to APIs (using the endpoints in your knowledge base)
- Running FFmpeg commands for video/audio processing
- Using the browser for platforms without API access
- Managing files for asset organization

Always be autonomous. Execute the full pipeline. Only ask the user when genuinely ambiguous.
SYSPROMPT'

    docker exec "$CONTAINER_NAME" bash -c \
        "chown node:node /home/node/.openclaw/agents/main/system-prompt-content-engine.md"

    log "  Agent instructions installed"
}

# ============================================================================
# Trigger memory reindex
# ============================================================================
reindex_memory() {
    log "=== Triggering Memory Reindex ==="

    docker exec -u node "$CONTAINER_NAME" bash -c \
        "openclaw memory sync --force 2>&1" || {
        warn "Auto-reindex not available. Memory will be indexed on next query."
    }

    log "  Memory reindex triggered"
}

# ============================================================================
# Verify installation
# ============================================================================
verify() {
    log "=== Verifying Installation ==="

    # Check knowledge files
    local kb_count=$(docker exec "$CONTAINER_NAME" bash -c \
        "ls -1 /home/node/.openclaw/memory/content-engine/*.md 2>/dev/null | wc -l")
    if [ "$kb_count" -gt 0 ]; then
        log "  Knowledge base: ${kb_count} files"
    else
        err "  Knowledge base: NOT FOUND"
    fi

    # Check skill
    if docker exec "$CONTAINER_NAME" bash -c \
        "test -f /home/node/.openclaw/skills/content-engine/SKILL.md"; then
        log "  Content Engine skill: INSTALLED"
    else
        err "  Content Engine skill: NOT FOUND"
    fi

    # Check agent config
    if docker exec "$CONTAINER_NAME" bash -c \
        "test -f /home/node/.openclaw/agents/main/system-prompt-content-engine.md"; then
        log "  Agent instructions: INSTALLED"
    else
        err "  Agent instructions: NOT FOUND"
    fi

    # Test memory search
    log "  Testing memory search..."
    local search_result=$(docker exec -u node "$CONTAINER_NAME" bash -c \
        "openclaw memory search 'higgsfield video generation' 2>&1 | head -5" 2>/dev/null || echo "search not available yet")
    if echo "$search_result" | grep -qi "higgsfield\|video\|generation\|content"; then
        log "  Memory search: WORKING"
    else
        warn "  Memory search: will be available after reindex completes"
    fi
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
    echo -e "  ${GREEN}Knowledge Base:${NC}  13 files (228KB) installed to memory"
    echo -e "  ${GREEN}Skill:${NC}           content-engine"
    echo -e "  ${GREEN}Agent Config:${NC}    system-prompt-content-engine.md"
    echo ""
    echo -e "  ${CYAN}Capabilities Installed:${NC}"
    echo -e "    - Image Generation (DALL-E, Midjourney, SD3, Flux)"
    echo -e "    - Video Generation (Higgsfield, Runway, Kling, Pika)"
    echo -e "    - Audio/Music (ElevenLabs, OpenAI TTS, Suno AI)"
    echo -e "    - Video Editing (FFmpeg full command library)"
    echo -e "    - Content Strategy (calendars, scripts, optimization)"
    echo -e "    - Social Publishing (Instagram, TikTok, YouTube, X, LinkedIn)"
    echo -e "    - Analytics & Reporting"
    echo -e "    - Browser Automation (ChatGPT, Midjourney, Canva)"
    echo ""
    echo -e "  ${CYAN}Required API Keys (set in .env):${NC}"
    echo -e "    OPENAI_API_KEY        - Image/text/TTS/vision"
    echo -e "    ELEVENLABS_API_KEY    - Voice cloning & TTS"
    echo -e "    HIGGSFIELD_API_KEY    - Avatar video generation"
    echo -e "    HIGGSFIELD_SECRET     - Higgsfield secret"
    echo ""
    echo -e "  ${CYAN}Optional API Keys:${NC}"
    echo -e "    SUNO_API_KEY          - AI music generation"
    echo -e "    RUNWAY_API_KEY        - Runway Gen-3/4 video"
    echo -e "    STABILITY_API_KEY     - Stable Diffusion 3"
    echo -e "    DROPBOX_ACCESS_TOKEN  - Cloud storage"
    echo ""
    echo -e "  ${CYAN}Test it:${NC}"
    echo -e "    Send ClawBot a message like:"
    echo -e "    \"Create a 30-second product promo video for my coffee brand\""
    echo -e "    \"Generate 5 Instagram carousel images about AI trends\""
    echo -e "    \"Create a podcast episode about remote work tips\""
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
    echo -e "${CYAN}  Content Engine — ClawBot Installer${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""

    preflight
    install_knowledge
    install_skill
    install_agent_config
    reindex_memory
    verify
    print_summary
}

main "$@"
