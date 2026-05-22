#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib/settings.sh"

echo ""
echo "================================"
echo "  Claude Vault — Configure"
echo "================================"
echo ""

# ── Find the vault ────────────────────────────────────────────────────────────

# Try global first, then ask
if [ -f "$HOME/.claude/vault/directives.md" ]; then
  VAULT_PATH="$HOME/.claude/vault"
  CLAUDE_MD="$HOME/.claude/CLAUDE.md"
  echo "Found vault at: $VAULT_PATH"
  echo ""
else
  read -p "Path to your vault folder (e.g. /Users/yourname/Work/my-project/vault): " VAULT_PATH
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

ask_settings

# ── Write updated settings block ─────────────────────────────────────────────

write_settings_block "$VAULT_PATH/directives.md"
echo "✓ Settings updated in directives.md"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "================================"
echo "  Settings saved."
echo "================================"
echo ""
echo "Changes are live from your next Claude Code session."
echo "You can also type /setup inside Claude Code to review or adjust further."
echo ""
