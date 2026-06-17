#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib/version.sh"

echo ""
echo "================================"
echo "  Claude Vault — Update"
echo "================================"
echo ""

LOCAL_VERSION="$VAULT_VERSION"
echo "Installed version: v$LOCAL_VERSION"

# ── Git check ────────────────────────────────────────────────────────────────

if [ ! -d "$SCRIPT_DIR/.git" ]; then
  echo ""
  echo "ERROR: This directory is not a git repository."
  echo "Clone claude-vault from GitHub and run install.sh to get update support."
  echo ""
  exit 1
fi

echo "Checking for updates..."
echo ""

if ! git -C "$SCRIPT_DIR" fetch origin main --quiet 2>/dev/null; then
  echo "ERROR: Could not reach remote. Check your internet connection and try again."
  echo ""
  exit 1
fi

# ── Version compare ───────────────────────────────────────────────────────────

REMOTE_VERSION=$(git -C "$SCRIPT_DIR" show origin/main:VERSION 2>/dev/null | tr -d '[:space:]' || true)

if [ -z "$REMOTE_VERSION" ]; then
  echo "ERROR: Could not read remote VERSION. The remote branch may be unavailable."
  echo ""
  exit 1
fi

echo "Latest version:    v$REMOTE_VERSION"
echo ""

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
  echo "You're up to date. Nothing to do."
  echo ""
  exit 0
fi

# ── Show changelog ────────────────────────────────────────────────────────────

echo "Update available: v$LOCAL_VERSION → v$REMOTE_VERSION"
echo ""
echo "What's new:"
git -C "$SCRIPT_DIR" log --oneline HEAD..origin/main
echo ""

read -p "Update now? (y/N): " UPDATE_CHOICE
echo ""

if [ "$UPDATE_CHOICE" != "y" ] && [ "$UPDATE_CHOICE" != "Y" ]; then
  echo "Update cancelled. Nothing changed."
  echo ""
  exit 0
fi

# ── Pull + reinstall ──────────────────────────────────────────────────────────

echo "Pulling latest changes..."
git -C "$SCRIPT_DIR" pull origin main --quiet
echo "✓ Pulled v$REMOTE_VERSION"
echo ""

echo "Applying update (using existing settings — no questions)..."
echo ""
printf '1\n' | bash "$SCRIPT_DIR/install.sh"
