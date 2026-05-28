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

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "──────────────────────────────────"
printf "  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo "──────────────────────────────────"
echo ""
[ "$FAIL" = 0 ]
