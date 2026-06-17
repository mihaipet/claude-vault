#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

assert_eq() {
  if [ "$1" = "$2" ]; then pass "$3"
  else fail "$3 — expected: '$2'  got: '$1'"; fi
}

assert_contains() {
  if grep -q "$1" "$2"; then pass "$3"
  else fail "$3 — expected '$1' in $2"; fi
}

assert_not_contains() {
  if ! grep -q "$1" "$2"; then pass "$3"
  else fail "$3 — unexpected '$1' found in $2"; fi
}

assert_file_exists() {
  if [ -f "$1" ]; then pass "$2"
  else fail "$2 — missing file: $1"; fi
}

assert_count() {
  local actual
  actual=$(grep -c "$1" "$2" 2>/dev/null || echo 0)
  if [ "$actual" = "$3" ]; then pass "$4"
  else fail "$4 — expected $3 occurrences of '$1', got $actual"; fi
}

source "$PROJECT_DIR/lib/settings.sh"

# ── read_current_settings ──────────────────────────────────────────────────────

echo ""
echo "read_current_settings"

FIXTURE="$TMPDIR_BASE/directives_fixture.md"
cat > "$FIXTURE" << 'FIXTURE_EOF'
# Directives

<!-- vault-settings-start -->
## About me
I am a designer. Prioritise visual thinking, component-level decisions, and design system conventions.

## Communication
- Be concise. Short answers. No padding, no unsolicited explanations.
- Confirm before implementing. Propose first, wait for my approval.
- Ask one clarifying question at a time, not a list
- If something is unclear, say so. Do not assume and proceed.
<!-- vault-settings-end -->

## How I like to work
- Custom user rule that must survive rewrites
FIXTURE_EOF

read_current_settings "$FIXTURE"

assert_eq "$CURRENT_ROLE_DIRECTIVE" \
  "I am a designer. Prioritise visual thinking, component-level decisions, and design system conventions." \
  "reads role correctly"
assert_eq "$CURRENT_LENGTH_DIRECTIVE" \
  "Be concise. Short answers. No padding, no unsolicited explanations." \
  "reads length directive correctly"
assert_eq "$CURRENT_CONFIRM_DIRECTIVE" \
  "Confirm before implementing. Propose first, wait for my approval." \
  "reads confirm directive correctly"

# No settings block — all return empty
CLEAN="$TMPDIR_BASE/directives_clean.md"
cp "$PROJECT_DIR/templates/directives.md" "$CLEAN"
read_current_settings "$CLEAN"
assert_eq "$CURRENT_ROLE_DIRECTIVE" "" "returns empty role when no block present"
assert_eq "$CURRENT_LENGTH_DIRECTIVE" "" "returns empty length when no block present"

# ── write_settings_block ───────────────────────────────────────────────────────

echo ""
echo "write_settings_block"

DIRECTIVES="$TMPDIR_BASE/directives_write.md"
cp "$PROJECT_DIR/templates/directives.md" "$DIRECTIVES"

ROLE_DIRECTIVE="I am a designer. Prioritise visual thinking, component-level decisions, and design system conventions."
LENGTH_DIRECTIVE="Be concise. Short answers. No padding, no unsolicited explanations."
CONFIRM_DIRECTIVE="Confirm before implementing. Propose first, wait for my approval."

write_settings_block "$DIRECTIVES"
assert_contains "<!-- vault-settings-start -->" "$DIRECTIVES" "start marker written"
assert_contains "<!-- vault-settings-end -->" "$DIRECTIVES" "end marker written"
assert_contains "I am a designer" "$DIRECTIVES" "role directive written"
assert_contains "Be concise" "$DIRECTIVES" "length directive written"
assert_contains "Confirm before" "$DIRECTIVES" "confirm directive written"

# Idempotent — second run must not duplicate the block
write_settings_block "$DIRECTIVES"
assert_count "<!-- vault-settings-start -->" "$DIRECTIVES" "1" "block not duplicated on re-run"

# Custom user content must survive rewrites
assert_contains "How I like to work" "$DIRECTIVES" "custom section preserved after write"

# ── detect_vault ───────────────────────────────────────────────────────────────

echo ""
echo "detect_vault"

source "$PROJECT_DIR/lib/vault.sh"

FAKE_VAULT="$TMPDIR_BASE/vault_detect"
mkdir -p "$FAKE_VAULT"
FAKE_HOME="$TMPDIR_BASE/home_detect"
mkdir -p "$FAKE_HOME/.claude"

_ORIG_HOME="$HOME"
HOME="$FAKE_HOME"

write_install_config "$FAKE_VAULT" "$FAKE_HOME/.claude/CLAUDE.md" "global" "1.0.0"
assert_file_exists "$FAKE_HOME/.claude/.vault-install" "install config written to correct location"

VAULT_PATH=""
CLAUDE_MD=""
detect_vault
assert_eq "$VAULT_PATH" "$FAKE_VAULT" "detect_vault returns vault path from install config"
assert_eq "$CLAUDE_MD" "$FAKE_HOME/.claude/CLAUDE.md" "detect_vault returns CLAUDE.md path from install config"

HOME="$_ORIG_HOME"

# ── uninstall: CLAUDE.md block removal ────────────────────────────────────────

echo ""
echo "uninstall — CLAUDE.md block removal"

FAKE_CLAUDE="$TMPDIR_BASE/CLAUDE_uninstall.md"
cat > "$FAKE_CLAUDE" << 'CLAUDE_EOF'
# My existing content

Some content before the vault block.

<!-- claude-vault-start -->

## Vault
- /path/to/vault/memory.md
- /path/to/vault/directives.md

<!-- claude-vault-end -->

Some content after the vault block.
CLAUDE_EOF

awk '
  /<!-- claude-vault-start -->/{skip=1; next}
  /<!-- claude-vault-end -->/{skip=0; next}
  !skip{print}
' "$FAKE_CLAUDE" > "$FAKE_CLAUDE.tmp"
mv "$FAKE_CLAUDE.tmp" "$FAKE_CLAUDE"

assert_not_contains "<!-- claude-vault-start -->" "$FAKE_CLAUDE" "vault block removed from CLAUDE.md"
assert_contains "My existing content" "$FAKE_CLAUDE" "content before block preserved"
assert_contains "Some content after" "$FAKE_CLAUDE" "content after block preserved"

# ── install config round-trip ─────────────────────────────────────────────────

echo ""
echo "install config round-trip"

FAKE_VAULT_RT="$TMPDIR_BASE/vault_rt"
mkdir -p "$FAKE_VAULT_RT"
FAKE_HOME_RT="$TMPDIR_BASE/home_rt"
mkdir -p "$FAKE_HOME_RT/.claude"

_ORIG_HOME_RT="$HOME"
HOME="$FAKE_HOME_RT"

write_install_config "$FAKE_VAULT_RT" "$FAKE_HOME_RT/.claude/CLAUDE.md" "global" "1.0.0"

VAULT_PATH=""
CLAUDE_MD=""
detect_vault
assert_eq "$VAULT_PATH" "$FAKE_VAULT_RT" "round-trip: vault path survives write/read"
assert_eq "$CLAUDE_MD" "$FAKE_HOME_RT/.claude/CLAUDE.md" "round-trip: CLAUDE.md path survives write/read"

HOME="$_ORIG_HOME_RT"

# ── list_plugins ───────────────────────────────────────────────────────────────

echo ""
echo "list_plugins"

source "$PROJECT_DIR/lib/plugins.sh"

FAKE_PLUGINS="$TMPDIR_BASE/plugins"
mkdir -p "$FAKE_PLUGINS/plugin-a"
mkdir -p "$FAKE_PLUGINS/plugin-b"
mkdir -p "$FAKE_PLUGINS/not-a-plugin"   # no manifest — must be ignored

cat > "$FAKE_PLUGINS/plugin-a/manifest.sh" << 'EOF'
PLUGIN_NAME="plugin-a"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Test plugin A"
PLUGIN_MIN_VAULT_VERSION="1.0.0"
EOF

cat > "$FAKE_PLUGINS/plugin-b/manifest.sh" << 'EOF'
PLUGIN_NAME="plugin-b"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Test plugin B"
PLUGIN_MIN_VAULT_VERSION="1.0.0"
EOF

FOUND_FILE="$TMPDIR_BASE/plugins_found.txt"
list_plugins "$FAKE_PLUGINS" > "$FOUND_FILE"

assert_contains "plugin-a" "$FOUND_FILE" "list_plugins finds plugin-a"
assert_contains "plugin-b" "$FOUND_FILE" "list_plugins finds plugin-b"
assert_not_contains "not-a-plugin" "$FOUND_FILE" "list_plugins skips dirs without manifest.sh"

# ── install_plugin ─────────────────────────────────────────────────────────────

echo ""
echo "install_plugin"

FAKE_PLUGIN_DIR="$TMPDIR_BASE/test_plugin/"
FAKE_PLUGIN_VAULT="$TMPDIR_BASE/test_plugin_vault"
FAKE_PLUGIN_SKILLS="$TMPDIR_BASE/test_plugin_skills"
mkdir -p "${FAKE_PLUGIN_DIR}skills/my-skill"
mkdir -p "${FAKE_PLUGIN_DIR}templates"
mkdir -p "$FAKE_PLUGIN_VAULT"
mkdir -p "$FAKE_PLUGIN_SKILLS"

cat > "${FAKE_PLUGIN_DIR}manifest.sh" << 'EOF'
PLUGIN_NAME="test-plugin"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Test plugin for install_plugin"
PLUGIN_MIN_VAULT_VERSION="1.0.0"
EOF

cat > "${FAKE_PLUGIN_DIR}skills/my-skill/SKILL.md" << 'EOF'
---
name: my-skill
description: A test skill
---
# My Skill
EOF

cat > "${FAKE_PLUGIN_DIR}templates/my-template.md" << 'EOF'
# My Template
Test content
EOF

install_plugin "$FAKE_PLUGIN_DIR" "$FAKE_PLUGIN_VAULT" "$FAKE_PLUGIN_SKILLS"

assert_file_exists "$FAKE_PLUGIN_SKILLS/my-skill/SKILL.md" "plugin skill installed to skills dir"
assert_file_exists "$FAKE_PLUGIN_VAULT/my-template.md" "plugin template copied to vault"

# Existing template must NOT be overwritten
echo "existing content" > "$FAKE_PLUGIN_VAULT/my-template.md"
install_plugin "$FAKE_PLUGIN_DIR" "$FAKE_PLUGIN_VAULT" "$FAKE_PLUGIN_SKILLS"
assert_contains "existing content" "$FAKE_PLUGIN_VAULT/my-template.md" "existing vault file not overwritten by plugin reinstall"

# ── write_persona_block ───────────────────────────────────────────────────────

echo ""
echo "write_persona_block"

PERSONA_DIR="$TMPDIR_BASE/persona"
mkdir -p "$PERSONA_DIR"

# skip → nothing written
PERSONA_FILE="$PERSONA_DIR/directives_skip.md"
echo "# Directives" > "$PERSONA_FILE"
PERSONA_CHOICE="skip" AI_NAME="" USER_PERSONA_WANTS_NAME=false write_persona_block "$PERSONA_FILE"
assert_not_contains "vault-persona-start" "$PERSONA_FILE" "skip: no persona block written"

# empty PERSONA_CHOICE → nothing written (reinstall case)
PERSONA_FILE="$PERSONA_DIR/directives_empty.md"
echo "# Directives" > "$PERSONA_FILE"
PERSONA_CHOICE="" AI_NAME="" USER_PERSONA_WANTS_NAME=false write_persona_block "$PERSONA_FILE"
assert_not_contains "vault-persona-start" "$PERSONA_FILE" "empty choice: no persona block written"

# named without user name
PERSONA_FILE="$PERSONA_DIR/directives_named.md"
echo "# Directives" > "$PERSONA_FILE"
USER_NAME="" USER_PERSONA_WANTS_NAME=false PERSONA_CHOICE="named" AI_NAME="Aria" write_persona_block "$PERSONA_FILE"
assert_contains "vault-persona-start" "$PERSONA_FILE" "named: persona block written"
assert_contains "Your name is Aria." "$PERSONA_FILE" "named: AI name written"
assert_not_contains "Address the user" "$PERSONA_FILE" "named: no user address line when USER_PERSONA_WANTS_NAME=false"

# named with user name
PERSONA_FILE="$PERSONA_DIR/directives_named_user.md"
echo "# Directives" > "$PERSONA_FILE"
USER_NAME="Alex" USER_PERSONA_WANTS_NAME=true PERSONA_CHOICE="named" AI_NAME="Max" write_persona_block "$PERSONA_FILE"
assert_contains "Your name is Max." "$PERSONA_FILE" "named+user: AI name written"
assert_contains "Address the user as Alex." "$PERSONA_FILE" "named+user: user address line written"

# ai-choose
PERSONA_FILE="$PERSONA_DIR/directives_ai_choose.md"
echo "# Directives" > "$PERSONA_FILE"
PERSONA_CHOICE="ai-choose" AI_NAME="choose" USER_PERSONA_WANTS_NAME=false write_persona_block "$PERSONA_FILE"
assert_contains "vault-persona-start" "$PERSONA_FILE" "ai-choose: persona block written"
assert_contains "not been given a name yet" "$PERSONA_FILE" "ai-choose: self-naming directive written"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "──────────────────────────────────"
printf "  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo "──────────────────────────────────"
echo ""
[ "$FAIL" = 0 ]
