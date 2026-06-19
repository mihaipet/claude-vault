#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib/vault.sh"
source "$SCRIPT_DIR/lib/version.sh"

echo ""
echo "================================"
echo "  Claude Vault — Uninstall"
echo "================================"
echo ""

# ── Detect install ────────────────────────────────────────────────────────────

if ! detect_vault; then
  echo "No Claude Vault install found. Nothing to do."
  echo ""
  exit 0
fi

echo "Found vault at: $VAULT_PATH"
echo ""
echo "This will remove:"
echo "  - Vault block from CLAUDE.md"
echo "  - Skills /vault-edit, /setup, /load-memory, /save-memory, /note, /update from ~/.claude/skills/"
echo "  - Install config at ~/.claude/.vault-install"
echo "  - Persona config at ~/.claude/.vault-persona"
echo ""
echo "This will NOT touch:"
echo "  - Your vault files (memory.md, directives.md, etc.) at $VAULT_PATH"
echo "  - Any other content in CLAUDE.md"
echo "  - Anything outside Claude Vault's managed marker blocks"
echo ""
read -p "Continue? (y/N): " CONFIRM
echo ""

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Uninstall cancelled. Nothing changed."
  exit 0
fi

# ── Remove vault block from CLAUDE.md ─────────────────────────────────────────

if [ -f "$CLAUDE_MD" ] && grep -q "$VAULT_CLAUDE_START" "$CLAUDE_MD"; then
  awk -v start="$VAULT_CLAUDE_START" -v end="$VAULT_CLAUDE_END" '
    $0 == start {skip=1; next}
    $0 == end   {skip=0; next}
    !skip{print}
  ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"
  mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
  echo "✓ Vault block removed from $CLAUDE_MD"
else
  echo "  (No vault block found in CLAUDE.md — skipped)"
fi

# ── Remove skills ─────────────────────────────────────────────────────────────

for skill in vault-edit setup load-memory save-memory note update; do
  skill_path="$HOME/.claude/skills/$skill"
  if [ -d "$skill_path" ]; then
    rm -rf "$skill_path"
    echo "✓ Removed skill: /$skill"
  fi
done

# ── Remove install config ─────────────────────────────────────────────────────

config_path="$HOME/.claude/.vault-install"
if [ -f "$config_path" ]; then
  rm "$config_path"
  echo "✓ Removed install config"
fi

persona_path="$HOME/.claude/.vault-persona"
if [ -f "$persona_path" ]; then
  rm "$persona_path"
  echo "✓ Removed persona config"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "================================"
echo "  Uninstall complete."
echo "================================"
echo ""
echo "Your vault files are still at: $VAULT_PATH"
echo "Delete them manually if you no longer need them:"
printf '  rm -rf "%s"\n' "$VAULT_PATH"
echo ""
