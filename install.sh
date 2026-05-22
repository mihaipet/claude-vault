#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DATE=$(date +%Y-%m-%d)

source "$SCRIPT_DIR/lib/settings.sh"

echo ""
echo "================================"
echo "  Claude Vault — Install"
echo "================================"
echo ""

# ── Re-run detection ──────────────────────────────────────────────────────────

if [ -d "$HOME/.claude/vault" ] || ([ -f "$HOME/.claude/CLAUDE.md" ] && grep -q "claude-vault-start" "$HOME/.claude/CLAUDE.md" 2>/dev/null); then
  echo "An existing install was found."
  echo ""
  echo "  1) Update settings only"
  echo "  2) Full reinstall (vault files preserved)"
  echo ""
  read -p "Enter 1 or 2: " REINSTALL_CHOICE
  echo ""
  if [ "$REINSTALL_CHOICE" = "1" ]; then
    exec "$SCRIPT_DIR/configure.sh"
    exit 0
  fi
fi

# ── Step 1: Name and project ──────────────────────────────────────────────────

read -p "Your name (e.g. Alex Kim): " USER_NAME
read -p "What are you working on? (e.g. mobile app redesign): " PROJECT_NAME
echo ""

# ── Step 2: Where to install ──────────────────────────────────────────────────

echo "Where should the vault live?"
echo ""
echo "  1) Global — works across all your projects (recommended)"
echo "  2) Project only — inside a specific project folder"
echo ""
read -p "Enter 1 or 2: " INSTALL_SCOPE
echo ""

IS_PROJECT_SCOPED=false

if [ "$INSTALL_SCOPE" = "2" ]; then
  read -p "Full path to your project folder (e.g. /Users/yourname/Work/my-project): " PROJECT_PATH
  if [ ! -d "$PROJECT_PATH" ]; then
    echo "ERROR: Directory not found: $PROJECT_PATH"
    echo "Check the path and run install.sh again."
    exit 1
  fi
  VAULT_PATH="$PROJECT_PATH/vault"
  CLAUDE_MD="$PROJECT_PATH/CLAUDE.md"
  IS_PROJECT_SCOPED=true
else
  VAULT_PATH="$HOME/.claude/vault"
  CLAUDE_MD="$HOME/.claude/CLAUDE.md"
fi

SKILLS_DEST="$HOME/.claude/skills"

# ── Step 3: Settings ──────────────────────────────────────────────────────────

ask_settings

# ── Step 4: Extra vault files ─────────────────────────────────────────────────

echo "Add optional starter files to your vault? (press Enter to skip)"
echo ""
echo "  1) team.md    — who's on the team, who decides what"
echo "  2) goals.md   — what you're trying to achieve this period"
echo "  3) stack.md   — tools, tech, conventions"
echo ""
read -p "Enter numbers separated by spaces, or press Enter to skip: " EXTRA_FILES_CHOICE
echo ""

# ── Step 5: Gitignore (project-scoped only) ───────────────────────────────────

if [ "$IS_PROJECT_SCOPED" = true ]; then
  read -p "Add vault/ to .gitignore? Keeps your notes private. (Y/n): " GIT_CHOICE
  echo ""
fi

echo "Installing..."
echo ""

# ── Step 6: Install skills ────────────────────────────────────────────────────

mkdir -p "$SKILLS_DEST/vault-edit"
mkdir -p "$SKILLS_DEST/setup"
cp "$SCRIPT_DIR/skills/vault-edit/SKILL.md" "$SKILLS_DEST/vault-edit/SKILL.md"
cp "$SCRIPT_DIR/skills/setup/SKILL.md" "$SKILLS_DEST/setup/SKILL.md"
echo "✓ Skills installed to $SKILLS_DEST"

# ── Step 7: Create vault and files ────────────────────────────────────────────

mkdir -p "$VAULT_PATH"

if [ ! -f "$VAULT_PATH/memory.md" ]; then
  sed \
    -e "s/{{NAME}}/$USER_NAME/g" \
    -e "s/{{PROJECT}}/$PROJECT_NAME/g" \
    -e "s/{{DATE}}/$INSTALL_DATE/g" \
    "$SCRIPT_DIR/templates/memory.md" > "$VAULT_PATH/memory.md"
  echo "✓ memory.md created"
else
  echo "✓ memory.md already exists — skipped"
fi

if [ ! -f "$VAULT_PATH/directives.md" ]; then
  cp "$SCRIPT_DIR/templates/directives.md" "$VAULT_PATH/directives.md"
  write_settings_block "$VAULT_PATH/directives.md"
  echo "✓ directives.md created"
else
  echo "✓ directives.md already exists — skipped"
fi

# Extra files
for choice in $EXTRA_FILES_CHOICE; do
  case "$choice" in
    1)
      if [ ! -f "$VAULT_PATH/team.md" ]; then
        cp "$SCRIPT_DIR/templates/team.md" "$VAULT_PATH/team.md"
        echo "✓ team.md created"
      else
        echo "✓ team.md already exists — skipped"
      fi ;;
    2)
      if [ ! -f "$VAULT_PATH/goals.md" ]; then
        cp "$SCRIPT_DIR/templates/goals.md" "$VAULT_PATH/goals.md"
        echo "✓ goals.md created"
      else
        echo "✓ goals.md already exists — skipped"
      fi ;;
    3)
      if [ ! -f "$VAULT_PATH/stack.md" ]; then
        cp "$SCRIPT_DIR/templates/stack.md" "$VAULT_PATH/stack.md"
        echo "✓ stack.md created"
      else
        echo "✓ stack.md already exists — skipped"
      fi ;;
  esac
done

# ── Step 8: Gitignore ─────────────────────────────────────────────────────────

if [ "$IS_PROJECT_SCOPED" = true ] && [ "$GIT_CHOICE" != "n" ] && [ "$GIT_CHOICE" != "N" ]; then
  GITIGNORE="$PROJECT_PATH/.gitignore"
  if [ -f "$GITIGNORE" ] && grep -q "^vault/$" "$GITIGNORE"; then
    echo "✓ vault/ already in .gitignore"
  else
    printf "\n# Claude Vault — local only, not committed\nvault/\n" >> "$GITIGNORE"
    echo "✓ vault/ added to .gitignore"
  fi
fi

# ── Step 9: CLAUDE.md ─────────────────────────────────────────────────────────

VAULT_BLOCK="<!-- claude-vault-start -->

## Vault
Persistent context files loaded every session.

- \`$VAULT_PATH/memory.md\` — current project state, recent decisions, lessons learned
- \`$VAULT_PATH/directives.md\` — standing rules, always follow these

Read both at the start of every session. Use /vault-edit to update them.
To change your settings, run \`configure.sh\` or type /setup in Claude Code.
<!-- claude-vault-end -->"

mkdir -p "$(dirname "$CLAUDE_MD")"

if [ -f "$CLAUDE_MD" ] && grep -q "<!-- claude-vault-start -->" "$CLAUDE_MD"; then
  awk '
    /<!-- claude-vault-start -->/{skip=1; next}
    /<!-- claude-vault-end -->/{skip=0; next}
    !skip{print}
  ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"
  mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
  printf "\n%s\n" "$VAULT_BLOCK" >> "$CLAUDE_MD"
  echo "✓ CLAUDE.md updated"
elif [ -f "$CLAUDE_MD" ]; then
  printf "\n%s\n" "$VAULT_BLOCK" >> "$CLAUDE_MD"
  echo "✓ Vault section appended to CLAUDE.md"
else
  printf "%s\n" "$VAULT_BLOCK" > "$CLAUDE_MD"
  echo "✓ CLAUDE.md created"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "================================"
echo "  Done. Your vault is ready."
echo "================================"
echo ""
echo "Your vault files:"
echo "  $VAULT_PATH/memory.md"
echo "  $VAULT_PATH/directives.md"
echo ""
echo "────────────────────────────────"
echo "  Commands available in Claude Code"
echo "────────────────────────────────"
echo ""
echo "  /vault-edit"
echo "    Update your second brain after a session."
echo "    Use it to log decisions, lessons, and open questions."
echo "    Also use it to add a new rule or create a new vault file."
echo ""
echo "  /setup"
echo "    Review and change your settings from inside Claude Code."
echo "    Change your role, response style, or confirmation behaviour"
echo "    without leaving your session."
echo ""
echo "────────────────────────────────"
echo "  Changing settings from the terminal"
echo "────────────────────────────────"
echo ""
echo "  ./configure.sh"
echo "    Re-runs the settings questions and updates directives.md."
echo "    Never touches your vault content."
echo ""
echo "────────────────────────────────"
echo "  What Claude reads every session"
echo "────────────────────────────────"
echo ""
echo "  memory.md      → your current focus, recent decisions, open questions"
echo "  directives.md  → standing rules Claude always follows"
echo ""
echo "Fill in memory.md with your current focus to get started."
echo ""
