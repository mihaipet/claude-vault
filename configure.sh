#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib/settings.sh"
source "$SCRIPT_DIR/lib/vault.sh"
source "$SCRIPT_DIR/lib/version.sh"

echo ""
echo "================================"
echo "  Claude Vault — Configure"
echo "================================"
echo ""

# ── Detect vault ──────────────────────────────────────────────────────────────

if detect_vault; then
  echo "Found vault at: $VAULT_PATH"
  echo ""
else
  read -p "Path to your vault folder: " VAULT_PATH
  CLAUDE_MD="$(dirname "$VAULT_PATH")/CLAUDE.md"
  if [ ! -d "$VAULT_PATH" ]; then
    echo "ERROR: Vault not found at $VAULT_PATH"
    echo "Run install.sh first."
    exit 1
  fi
  echo ""
fi

# ── Settings questions ────────────────────────────────────────────────────────

echo "Update your settings. Press Enter on any question to keep the current value."
echo ""

ask_settings "$VAULT_PATH/directives.md"

# ── Write updated settings block ──────────────────────────────────────────────

write_settings_block "$VAULT_PATH/directives.md"
echo "✓ Settings updated in directives.md"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "================================"
echo "  Settings saved."
echo "================================"
echo ""
echo "Changes are live from your next Claude Code session."
echo "Type /setup in Claude Code to review or adjust further."
echo ""
