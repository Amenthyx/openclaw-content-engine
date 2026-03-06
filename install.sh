#!/usr/bin/env bash
# ============================================================================
# Content Engine — Interactive Installer
# Supports: Local install, Docker container, Custom path
# Configures OpenClaw plugins, browser, and credentials
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

INSTALL_MODE=""
OPENCLAW_HOME=""
CONTAINER_NAME=""

# ============================================================================
# Detect installations
# ============================================================================
detect_installations() {
    echo ""
    log "Scanning for OpenClaw installations..."
    echo ""

    local found_local=false
    local found_docker=false
    local local_path=""
    local docker_containers=""

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

    local openclaw_bin=""
    if command -v openclaw &>/dev/null; then
        openclaw_bin=$(command -v openclaw)
    fi

    if command -v docker &>/dev/null; then
        docker_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i "claw" || true)
        [ -n "$docker_containers" ] && found_docker=true
    fi

    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  OpenClaw Content Engine — Installer${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${BOLD}Detected Installations:${NC}"
    echo ""

    if $found_local; then
        echo -e "  ${GREEN}[LOCAL]${NC}   Config: ${BOLD}${local_path}${NC}"
        [ -n "$openclaw_bin" ] && echo -e "            Binary: ${openclaw_bin}"
    fi
    if $found_docker; then
        echo -e "  ${GREEN}[DOCKER]${NC}  Containers:"
        echo "$docker_containers" | while read -r name; do
            echo -e "            - ${BOLD}${name}${NC}"
        done
    fi
    if ! $found_local && ! $found_docker; then
        echo -e "  ${YELLOW}No installations detected.${NC}"
    fi

    echo ""
    echo -e "${CYAN}------------------------------------------------------------${NC}"
    echo ""
    echo -e "  ${BOLD}Where do you want to install?${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Local install"
    $found_local && echo -e "     → ${local_path}" || echo -e "     → ~/.openclaw"
    echo ""
    echo -e "  ${BOLD}2)${NC} Docker container"
    $found_docker && echo -e "     → Container: $(echo "$docker_containers" | head -1)" || echo -e "     → Specify container name"
    echo ""
    echo -e "  ${BOLD}3)${NC} Custom path"
    echo ""

    while true; do
        echo -ne "  ${BOLD}Choose [1/2/3]:${NC} "
        read -r choice
        case "$choice" in
            1)
                INSTALL_MODE="local"
                OPENCLAW_HOME="${local_path:-$HOME/.openclaw}"
                break ;;
            2)
                INSTALL_MODE="docker"
                if $found_docker; then
                    CONTAINER_NAME=$(echo "$docker_containers" | head -1)
                    echo -ne "  Container [${CONTAINER_NAME}]: "
                    read -r cn; [ -n "$cn" ] && CONTAINER_NAME="$cn"
                else
                    echo -ne "  Container name: "
                    read -r CONTAINER_NAME
                    [ -z "$CONTAINER_NAME" ] && { err "Required."; continue; }
                fi
                docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" || { err "'${CONTAINER_NAME}' not running."; continue; }
                break ;;
            3)
                echo -ne "  OpenClaw config path: "
                read -r cp
                [ -z "$cp" ] && { err "Required."; continue; }
                INSTALL_MODE="local"; OPENCLAW_HOME="$cp"
                break ;;
            *) warn "Enter 1, 2, or 3." ;;
        esac
    done

    echo ""
    [ "$INSTALL_MODE" = "local" ] && log "Mode: LOCAL → ${OPENCLAW_HOME}" || log "Mode: DOCKER → ${CONTAINER_NAME}"
    echo ""
}

# ============================================================================
# Run openclaw config commands (local or docker)
# ============================================================================
oc_config() {
    if [ "$INSTALL_MODE" = "local" ]; then
        openclaw config "$@" 2>/dev/null || true
    else
        docker exec -u node "$CONTAINER_NAME" openclaw config "$@" 2>/dev/null || true
    fi
}

oc_cmd() {
    if [ "$INSTALL_MODE" = "local" ]; then
        openclaw "$@" 2>/dev/null || true
    else
        docker exec -u node "$CONTAINER_NAME" openclaw "$@" 2>/dev/null || true
    fi
}

# ============================================================================
# Install knowledge base
# ============================================================================
install_knowledge() {
    log "=== [1/6] Installing Knowledge Base ==="

    if [ "$INSTALL_MODE" = "local" ]; then
        mkdir -p "${OPENCLAW_HOME}/memory/content-engine"
        for f in "$KNOWLEDGE_DIR"/*.md; do
            cp "$f" "${OPENCLAW_HOME}/memory/content-engine/$(basename "$f")"
        done
    else
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p /home/node/.openclaw/memory/content-engine"
        for f in "$KNOWLEDGE_DIR"/*.md; do
            docker cp "$f" "${CONTAINER_NAME}:/home/node/.openclaw/memory/content-engine/$(basename "$f")"
        done
        docker exec "$CONTAINER_NAME" bash -c "chown -R node:node /home/node/.openclaw/memory" 2>/dev/null || true
    fi

    local count=$(ls -1 "$KNOWLEDGE_DIR"/*.md | wc -l)
    log "  ${count} knowledge files installed"
}

# ============================================================================
# Install skill
# ============================================================================
install_skill() {
    log "=== [2/6] Installing Skill ==="

    if [ "$INSTALL_MODE" = "local" ]; then
        mkdir -p "${OPENCLAW_HOME}/skills/content-engine"
        cp "$SKILL_DIR/SKILL.md" "${OPENCLAW_HOME}/skills/content-engine/SKILL.md"
        [ -d "$SKILL_DIR/scripts" ] && cp -r "$SKILL_DIR/scripts" "${OPENCLAW_HOME}/skills/content-engine/"
    else
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p /home/node/.openclaw/skills/content-engine"
        docker cp "$SKILL_DIR/SKILL.md" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/SKILL.md"
        [ -d "$SKILL_DIR/scripts" ] && docker cp "$SKILL_DIR/scripts" "${CONTAINER_NAME}:/home/node/.openclaw/skills/content-engine/"
        docker exec "$CONTAINER_NAME" bash -c "chown -R node:node /home/node/.openclaw/skills/content-engine" 2>/dev/null || true
    fi

    log "  content-engine skill installed"
}

# ============================================================================
# Enable required plugins and configure OpenClaw
# ============================================================================
configure_openclaw() {
    log "=== [3/6] Configuring OpenClaw Plugins & Tools ==="

    # Enable lobster plugin (browser tools for the agent)
    log "  Enabling lobster plugin (browser tools)..."
    oc_config set plugins.entries.lobster.enabled true

    # Enable llm-task plugin (background task execution)
    log "  Enabling llm-task plugin (background tasks)..."
    oc_config set plugins.entries.llm-task.enabled true

    # Allow all tools (needed for browser + exec)
    log "  Setting tool permissions..."
    oc_config set tools.allow '["*"]'

    # Enable elevated tools from Telegram
    log "  Enabling elevated tools from Telegram..."
    oc_config set tools.elevated.enabled true

    # Set sandbox off (needed for browser and file system access)
    log "  Configuring sandbox mode..."
    oc_config set agents.defaults.sandbox.mode off

    # Set workspace directory
    if [ "$INSTALL_MODE" = "local" ]; then
        log "  Setting workspace..."
        oc_config set agents.defaults.workspace "${OPENCLAW_HOME}/workspace"
    fi

    log "  Plugins and tools configured"
}

# ============================================================================
# Deploy credentials template
# ============================================================================
deploy_credentials() {
    log "=== [4/6] Setting Up Credentials ==="

    if [ "$INSTALL_MODE" = "local" ]; then
        if [ -f "${OPENCLAW_HOME}/credentials.json" ]; then
            log "  credentials.json exists — skipping"
        else
            cp "$CREDS_TEMPLATE" "${OPENCLAW_HOME}/credentials.json"
            chmod 600 "${OPENCLAW_HOME}/credentials.json" 2>/dev/null || true
            warn "  credentials.json created — ADD YOUR LOGINS:"
            warn "  ${OPENCLAW_HOME}/credentials.json"
        fi
        mkdir -p "${OPENCLAW_HOME}/sessions" "${OPENCLAW_HOME}/workspace"
    else
        if docker exec "$CONTAINER_NAME" bash -c "test -f /home/node/.openclaw/credentials.json" 2>/dev/null; then
            log "  credentials.json exists — skipping"
        else
            docker cp "$CREDS_TEMPLATE" "${CONTAINER_NAME}:/home/node/.openclaw/credentials.json"
            docker exec "$CONTAINER_NAME" bash -c "chown node:node /home/node/.openclaw/credentials.json && chmod 600 /home/node/.openclaw/credentials.json" 2>/dev/null || true
            warn "  credentials.json deployed — EDIT IT:"
            warn "  docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json"
        fi
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p /home/node/.openclaw/sessions /home/node/.openclaw/workspace" 2>/dev/null || true
    fi

    log "  Credentials and directories ready"
}

# ============================================================================
# Reindex memory
# ============================================================================
reindex_memory() {
    log "=== [5/6] Indexing Memory ==="
    oc_cmd memory index --force
    log "  Memory indexed"
}

# ============================================================================
# Verify
# ============================================================================
verify() {
    log "=== [6/6] Verifying Installation ==="

    if [ "$INSTALL_MODE" = "local" ]; then
        [ -d "${OPENCLAW_HOME}/memory/content-engine" ] \
            && log "  Knowledge: $(ls -1 "${OPENCLAW_HOME}/memory/content-engine/"*.md 2>/dev/null | wc -l) files" \
            || err "  Knowledge: NOT FOUND"
        [ -f "${OPENCLAW_HOME}/skills/content-engine/SKILL.md" ] \
            && log "  Skill: INSTALLED" || err "  Skill: NOT FOUND"
        [ -f "${OPENCLAW_HOME}/credentials.json" ] \
            && log "  Credentials: PRESENT" || warn "  Credentials: NOT CONFIGURED"
    else
        local c=$(docker exec "$CONTAINER_NAME" bash -c "ls -1 /home/node/.openclaw/memory/content-engine/*.md 2>/dev/null | wc -l")
        [ "$c" -gt 0 ] && log "  Knowledge: ${c} files" || err "  Knowledge: NOT FOUND"
        docker exec "$CONTAINER_NAME" bash -c "test -f /home/node/.openclaw/skills/content-engine/SKILL.md" 2>/dev/null \
            && log "  Skill: INSTALLED" || err "  Skill: NOT FOUND"
        docker exec "$CONTAINER_NAME" bash -c "test -f /home/node/.openclaw/credentials.json" 2>/dev/null \
            && log "  Credentials: PRESENT" || warn "  Credentials: NOT CONFIGURED"
    fi

    # Check plugins
    log "  Checking plugin status..."
    oc_cmd skills list 2>/dev/null | grep "content-engine" || warn "  Skill not yet visible (may need gateway restart)"
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
    echo ""
    echo -e "  ${GREEN}What was installed:${NC}"
    echo -e "    - 13 knowledge files (memory/content-engine/)"
    echo -e "    - content-engine skill"
    echo -e "    - credentials.json template"
    echo ""
    echo -e "  ${GREEN}What was configured:${NC}"
    echo -e "    - lobster plugin ENABLED (browser tools for agent)"
    echo -e "    - llm-task plugin ENABLED (background tasks)"
    echo -e "    - tools.allow = [\"*\"] (full tool access)"
    echo -e "    - sandbox.mode = off (browser + file access)"
    echo ""

    if [ "$INSTALL_MODE" = "local" ]; then
        echo -e "  ${CYAN}Next Steps:${NC}"
        echo ""
        echo -e "    ${BOLD}1. Add your platform logins:${NC}"
        echo -e "       ${YELLOW}nano ${OPENCLAW_HOME}/credentials.json${NC}"
        echo ""
        echo -e "    ${BOLD}2. Restart OpenClaw gateway:${NC}"
        echo -e "       ${YELLOW}openclaw gateway restart${NC}"
        echo ""
        echo -e "    ${BOLD}3. Test it — send via Telegram:${NC}"
        echo -e "       \"Open the browser and go to chat.openai.com\""
    else
        echo -e "  ${CYAN}Next Steps:${NC}"
        echo ""
        echo -e "    ${BOLD}1. Add your platform logins:${NC}"
        echo -e "       ${YELLOW}docker exec -it ${CONTAINER_NAME} nano /home/node/.openclaw/credentials.json${NC}"
        echo ""
        echo -e "    ${BOLD}2. Restart the container:${NC}"
        echo -e "       ${YELLOW}docker restart ${CONTAINER_NAME}${NC}"
        echo ""
        echo -e "    ${BOLD}3. Test it — send via Telegram:${NC}"
        echo -e "       \"Open the browser and go to chat.openai.com\""
    fi

    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================
main() {
    if [ ! -d "$KNOWLEDGE_DIR" ] || [ -z "$(ls -A "$KNOWLEDGE_DIR"/*.md 2>/dev/null)" ]; then
        err "Knowledge directory not found: $KNOWLEDGE_DIR"
        err "Run this script from the openclaw-content-engine directory."
        exit 1
    fi

    detect_installations
    install_knowledge
    install_skill
    configure_openclaw
    deploy_credentials
    reindex_memory
    verify
    print_summary
}

main "$@"
