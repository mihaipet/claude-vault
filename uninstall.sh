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
echo "  - Skills /vault-edit and /setup from ~/.claude/skills/"
echo "  - Install config at ~/.claude/.vault-install"
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

if [ -f "$CLAUDE_MD" ] && grep -q "<!-- claude-vault-start -->" "$CLAUDE_MD"; then
  awk '
    /<!-- claude-vault-start -->/{skip=1; next}
    /<!-- claude-vault-end -->/{skip=0; next}
    !skip{print}
  ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"
  mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
  echo "✓ Vault block removed from $CLAUDE_MD"
else
  echo "  (No vault block found in CLAUDE.md — skipped)"
fi

# ── Remove skills ─────────────────────────────────────────────────────────────

for skill in vault-edit setup; do
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
