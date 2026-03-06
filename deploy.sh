#!/bin/bash
# OpenClaw Content Engine — Knowledge Base Deployer
# Copies knowledge files into OpenClaw's memory directory for auto-indexing

set -e

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
MEMORY_DIR="$OPENCLAW_HOME/memory"
KNOWLEDGE_SRC="$(dirname "$0")/knowledge"
SKILL_SRC="$(dirname "$0")/skills"
OPENCLAW_SKILLS="${OPENCLAW_HOME}/skills"

echo "=== OpenClaw Content Engine Deployer ==="
echo ""

# 1. Deploy knowledge files to memory
echo "[1/3] Deploying knowledge files to OpenClaw memory..."
mkdir -p "$MEMORY_DIR/content-engine"

for f in "$KNOWLEDGE_SRC"/*.md; do
  if [ -f "$f" ]; then
    filename=$(basename "$f")
    cp "$f" "$MEMORY_DIR/content-engine/$filename"
    echo "  ✓ $filename"
  fi
done

# 2. Deploy skills
echo ""
echo "[2/3] Deploying skills..."
for skill_dir in "$SKILL_SRC"/*/; do
  if [ -d "$skill_dir" ]; then
    skill_name=$(basename "$skill_dir")
    target="$OPENCLAW_SKILLS/$skill_name"
    mkdir -p "$target"
    cp -r "$skill_dir"* "$target/"
    echo "  ✓ skill: $skill_name"
  fi
done

# 3. Trigger memory reindex
echo ""
echo "[3/3] Triggering memory reindex..."
if command -v openclaw &> /dev/null; then
  openclaw memory sync --force 2>/dev/null || echo "  ⚠ Auto-sync not available. Run 'openclaw memory sync' manually."
else
  echo "  ⚠ openclaw CLI not found. Run 'openclaw memory sync' manually after install."
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Knowledge files: $MEMORY_DIR/content-engine/"
echo "Skills: $OPENCLAW_SKILLS/"
echo ""
echo "OpenClaw will auto-index these files on next startup."
echo "To force reindex: openclaw memory sync --force"
echo "To search: openclaw memory search 'how to generate video with higgsfield'"
