#!/usr/bin/env bash
# Integration test suite for claude-vault
# Covers: install, reinstall, idempotency, uninstall, persona, settings
#
# Note: a fresh install needs interactive answers, so tests that pipe partial
# input may see install.sh exit non-zero when a `read` hits EOF under `set -e` —
# expected, not a bug. The "use existing setup" path IS non-interactive and exits
# 0 (install.sh guards its prompts behind `if ! $_use_existing`). Tests use
# "|| true" on installer calls and assert on artifacts only.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0; FAIL=0
pass() { echo "  ✓  $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗  $1"; FAIL=$((FAIL+1)); }
assert_file_exists() { [ -f "$1" ] && pass "$2" || fail "$2 — missing: $1"; }
assert_dir_exists()  { [ -d "$1" ] && pass "$2" || fail "$2 — missing: $1"; }
assert_contains()    { grep -q "$1" "$2" && pass "$3" || fail "$3 — '$1' not in $2"; }
assert_not_contains(){ ! grep -q "$1" "$2" && pass "$3" || fail "$3 — '$1' found in $2"; }
assert_file_missing(){ [ ! -f "$1" ] && pass "$2" || fail "$2 — file still exists: $1"; }

# stdin for a fresh global install (8 lines):
#   name, project, scope=1(global), role=2(dev), length=1(concise),
#   confirm=1(confirm-first), extra-files=empty, persona=skip
fresh_install_stdin() {
  printf 'Test User\nTest Project\n1\n2\n1\n1\n\nskip\n'
}

# stdin for reinstall using existing settings (option 1) — one keystroke, no questions
reinstall_stdin() {
  printf '1\n'
}

# stdin for reinstall with full redo (option 2) — answers everything fresh, no persona question
# (because .vault-persona already exists from the first install)
reinstall_redo_stdin() {
  printf '2\nTest User 2\nTest Project 2\n1\n2\n1\n1\n\n'
}

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "================================"
echo "  Integration Tests"
echo "================================"
echo ""

# ─── TC-INT-001: Fresh global install ────────────────────────────────────────
echo "TC-INT-001: Fresh global install"
INT001_HOME="$(mktemp -d)"
export HOME="$INT001_HOME"

fresh_install_stdin | bash "$REPO/install.sh" >/dev/null 2>&1 || true

VAULT="$INT001_HOME/.claude/vault"
CLAUDE_MD="$INT001_HOME/.claude/CLAUDE.md"
SKILLS="$INT001_HOME/.claude/skills"

assert_file_exists "$VAULT/memory.md"          "memory.md created"
assert_file_exists "$VAULT/directives.md"      "directives.md created"
assert_file_exists "$CLAUDE_MD"                "CLAUDE.md created"
assert_file_exists "$INT001_HOME/.claude/.vault-install" ".vault-install created"

assert_dir_exists  "$SKILLS/load-memory"       "skill load-memory installed"
assert_dir_exists  "$SKILLS/save-memory"       "skill save-memory installed"
assert_dir_exists  "$SKILLS/note"              "skill note installed"
assert_dir_exists  "$SKILLS/vault-edit"        "skill vault-edit installed"
assert_dir_exists  "$SKILLS/setup"             "skill setup installed"
assert_dir_exists  "$SKILLS/update"            "skill update installed"

assert_contains    "Test User"    "$VAULT/memory.md"  "memory.md contains user name"
assert_contains    "Test Project" "$VAULT/memory.md"  "memory.md contains project name"

assert_contains    "<!-- claude-vault-start -->" "$CLAUDE_MD" "CLAUDE.md contains vault start marker"

assert_contains    "VAULT_PATH" "$INT001_HOME/.claude/.vault-install" ".vault-install contains VAULT_PATH"
assert_contains    "REPO_PATH"  "$INT001_HOME/.claude/.vault-install" ".vault-install contains REPO_PATH"

assert_contains    "PERSONA_SETUP=skip" "$INT001_HOME/.claude/.vault-persona" ".vault-persona contains PERSONA_SETUP=skip"

echo ""

# ─── TC-INT-002: Vault files NOT overwritten on reinstall ────────────────────
echo "TC-INT-002: Vault files NOT overwritten on reinstall"
# Continue from INT-001 state (same HOME)
echo "SENTINEL_DO_NOT_OVERWRITE" >> "$VAULT/memory.md"

reinstall_stdin | bash "$REPO/install.sh" >/dev/null 2>&1 || true

assert_contains    "SENTINEL_DO_NOT_OVERWRITE" "$VAULT/memory.md" "memory.md sentinel preserved"
assert_file_exists "$VAULT/directives.md"                         "directives.md still exists"
echo ""

# ─── TC-INT-003: CLAUDE.md block is idempotent (no duplicates) ───────────────
echo "TC-INT-003: CLAUDE.md block is idempotent (no duplicates)"
# Continue from INT-002 state (same HOME)
reinstall_stdin | bash "$REPO/install.sh" >/dev/null 2>&1 || true

start_count=$(grep -c "<!-- claude-vault-start -->" "$CLAUDE_MD" || true)
end_count=$(grep -c "<!-- claude-vault-end -->" "$CLAUDE_MD" || true)

[ "$start_count" -eq 1 ] \
  && pass "CLAUDE.md has exactly 1 vault-start marker" \
  || fail "CLAUDE.md has $start_count vault-start markers (expected 1)"

[ "$end_count" -eq 1 ] \
  && pass "CLAUDE.md has exactly 1 vault-end marker" \
  || fail "CLAUDE.md has $end_count vault-end markers (expected 1)"

echo ""

# ─── TC-INT-004: Existing CLAUDE.md content preserved ────────────────────────
echo "TC-INT-004: Existing CLAUDE.md content preserved"
INT004_HOME="$(mktemp -d)"
export HOME="$INT004_HOME"

mkdir -p "$INT004_HOME/.claude"
printf '# My Rules\ndo the thing\n' > "$INT004_HOME/.claude/CLAUDE.md"

fresh_install_stdin | bash "$REPO/install.sh" >/dev/null 2>&1 || true

assert_contains "do the thing"              "$INT004_HOME/.claude/CLAUDE.md" "existing CLAUDE.md content preserved"
assert_contains "<!-- claude-vault-start -->" "$INT004_HOME/.claude/CLAUDE.md" "vault block present in CLAUDE.md"
echo ""

# ─── TC-INT-005: Persona named — identity block written to directives.md ─────
echo "TC-INT-005: Persona named — identity block written to directives.md"
INT005_HOME="$(mktemp -d)"
export HOME="$INT005_HOME"

# stdin: name, project, scope=1, role=2, length=1, confirm=1, extra-files=empty,
#        persona=Aria, user-name-pref=skip (follow-up "address you as X?" question)
printf 'Test User\nTest Project\n1\n2\n1\n1\n\nAria\nskip\n' \
  | bash "$REPO/install.sh" >/dev/null 2>&1 || true

DIRECTIVES005="$INT005_HOME/.claude/vault/directives.md"

assert_contains "<!-- vault-persona-start -->" "$DIRECTIVES005" "directives.md has persona-start marker"
assert_contains "Your name is Aria."           "$DIRECTIVES005" "directives.md contains AI name"
assert_contains "AI_NAME=Aria"                 "$INT005_HOME/.claude/.vault-persona" ".vault-persona has AI_NAME=Aria"
echo ""

# ─── TC-INT-006: Persona ai-choose — self-naming directive written ────────────
echo "TC-INT-006: Persona ai-choose — self-naming directive written"
INT006_HOME="$(mktemp -d)"
export HOME="$INT006_HOME"

# stdin: name, project, scope=1, role=2, length=1, confirm=1, extra-files=empty,
#        persona=<Enter> (empty = ai-choose)
printf 'Test User\nTest Project\n1\n2\n1\n1\n\n\n' \
  | bash "$REPO/install.sh" >/dev/null 2>&1 || true

DIRECTIVES006="$INT006_HOME/.claude/vault/directives.md"

assert_contains "not been given a name yet"    "$DIRECTIVES006" "directives.md contains ai-choose directive"
assert_contains "PERSONA_SETUP=ai-choose"      "$INT006_HOME/.claude/.vault-persona" ".vault-persona has PERSONA_SETUP=ai-choose"
echo ""

# ─── TC-INT-007: Uninstall removes block + skills, preserves vault ────────────
echo "TC-INT-007: Uninstall removes block + skills, preserves vault"
INT007_HOME="$(mktemp -d)"
export HOME="$INT007_HOME"

fresh_install_stdin | bash "$REPO/install.sh" >/dev/null 2>&1 || true

printf 'y\n' | bash "$REPO/uninstall.sh" >/dev/null 2>&1 || true

CLAUDE_MD007="$INT007_HOME/.claude/CLAUDE.md"

assert_not_contains "<!-- claude-vault-start -->" "$CLAUDE_MD007" "vault block removed from CLAUDE.md"

[ ! -d "$INT007_HOME/.claude/skills/vault-edit" ] \
  && pass "skill vault-edit removed" \
  || fail "skill vault-edit still present"

[ ! -d "$INT007_HOME/.claude/skills/setup" ] \
  && pass "skill setup removed" \
  || fail "skill setup still present"

[ ! -d "$INT007_HOME/.claude/skills/update" ] \
  && pass "skill update removed" \
  || fail "skill update still present"

assert_file_exists  "$INT007_HOME/.claude/vault/memory.md" "memory.md preserved after uninstall"
assert_file_missing "$INT007_HOME/.claude/.vault-install"  ".vault-install removed"
echo ""

# ─── TC-INT-008: Settings block updated on reinstall, not duplicated ──────────
echo "TC-INT-008: Settings block updated on reinstall, not duplicated"
INT008_HOME="$(mktemp -d)"
export HOME="$INT008_HOME"

fresh_install_stdin    | bash "$REPO/install.sh" >/dev/null 2>&1 || true
reinstall_redo_stdin   | bash "$REPO/install.sh" >/dev/null 2>&1 || true

DIRECTIVES008="$INT008_HOME/.claude/vault/directives.md"

settings_start_count=$(grep -c "vault-settings-start" "$DIRECTIVES008" || true)
settings_end_count=$(grep -c "vault-settings-end" "$DIRECTIVES008" || true)

[ "$settings_start_count" -eq 1 ] \
  && pass "directives.md has exactly 1 vault-settings-start" \
  || fail "directives.md has $settings_start_count vault-settings-start (expected 1)"

[ "$settings_end_count" -eq 1 ] \
  && pass "directives.md has exactly 1 vault-settings-end" \
  || fail "directives.md has $settings_end_count vault-settings-end (expected 1)"

echo ""

# ─── TC-INT-009: Use existing setup — no prompts, skills updated ─────────────
echo "TC-INT-009: Use existing setup — one keystroke reinstall"
INT009_HOME="$(mktemp -d)"
export HOME="$INT009_HOME"

fresh_install_stdin | bash "$REPO/install.sh" >/dev/null 2>&1 || true
reinstall_stdin     | bash "$REPO/install.sh" >/dev/null 2>&1 || true

VAULT009="$INT009_HOME/.claude/vault"
CLAUDE_MD009="$INT009_HOME/.claude/CLAUDE.md"

assert_file_exists "$VAULT009/memory.md"      "memory.md preserved after use-existing reinstall"
assert_file_exists "$VAULT009/directives.md"  "directives.md preserved after use-existing reinstall"
assert_contains    "Test User"    "$VAULT009/memory.md" "memory.md still has original user name"
assert_contains    "Test Project" "$VAULT009/memory.md" "memory.md still has original project name"
assert_file_exists "$INT009_HOME/.claude/skills/load-memory/SKILL.md" "load-memory skill present"
assert_file_exists "$INT009_HOME/.claude/skills/save-memory/SKILL.md" "save-memory skill present"
assert_file_exists "$INT009_HOME/.claude/skills/note/SKILL.md"        "note skill present"
assert_contains    "USER_NAME"    "$INT009_HOME/.claude/.vault-install" ".vault-install has USER_NAME"
assert_contains    "PROJECT_NAME" "$INT009_HOME/.claude/.vault-install" ".vault-install has PROJECT_NAME"
assert_contains    "REPO_PATH"    "$INT009_HOME/.claude/.vault-install" ".vault-install has REPO_PATH"

echo ""

# ─── TC-INT-010: update.sh — version check and update flow ───────────────────
echo "TC-INT-010: update.sh — version check, accept, decline"
INT010_HOME="$(mktemp -d)"
export HOME="$INT010_HOME"

INT010_REMOTE="$(mktemp -d)"
INT010_LOCAL="$(mktemp -d)"

# Set up a bare remote and a local vault copy pointing to it
git init --bare "$INT010_REMOTE" --quiet
cp -r "$REPO"/. "$INT010_LOCAL/"
git -C "$INT010_LOCAL" init --quiet
git -C "$INT010_LOCAL" symbolic-ref HEAD refs/heads/main
git -C "$INT010_LOCAL" config user.email "qa@test"
git -C "$INT010_LOCAL" config user.name "QA"
git -C "$INT010_LOCAL" add -A
git -C "$INT010_LOCAL" commit -m "initial" --quiet
git -C "$INT010_LOCAL" remote add origin "$INT010_REMOTE"
git -C "$INT010_LOCAL" push origin main --quiet 2>/dev/null || true

# Fresh install into INT010_HOME so use-existing path works after update
fresh_install_stdin | bash "$INT010_LOCAL/install.sh" >/dev/null 2>&1 || true

# ── A: same version → up to date ─────────────────────────────────────────────
_output=$(bash "$INT010_LOCAL/update.sh" 2>&1 || true)
echo "$_output" | grep -qi "up to date" \
  && pass "TC-INT-010a: reports up to date when versions match" \
  || fail "TC-INT-010a: did not report up to date"

# ── B: bump remote version → accept update ───────────────────────────────────
INT010_CLONE="$(mktemp -d)"
git clone "$INT010_REMOTE" "$INT010_CLONE" --quiet 2>/dev/null || true
git -C "$INT010_CLONE" config user.email "qa@test"
git -C "$INT010_CLONE" config user.name "QA"
echo "99.0.0" > "$INT010_CLONE/VERSION"
git -C "$INT010_CLONE" add VERSION
git -C "$INT010_CLONE" commit -m "bump to 99.0.0" --quiet
git -C "$INT010_CLONE" push --quiet 2>/dev/null || true

_output=$(printf 'y\n' | bash "$INT010_LOCAL/update.sh" 2>&1 || true)
echo "$_output" | grep -q "Pulled\|Pulling" \
  && pass "TC-INT-010b: pulled when update accepted" \
  || fail "TC-INT-010b: did not pull"
_local_ver=$(cat "$INT010_LOCAL/VERSION" 2>/dev/null || echo "")
[ "$_local_ver" = "99.0.0" ] \
  && pass "TC-INT-010b: VERSION updated to 99.0.0" \
  || fail "TC-INT-010b: VERSION not updated (got: $_local_ver)"

# ── C: bump remote again → decline update ────────────────────────────────────
echo "100.0.0" > "$INT010_CLONE/VERSION"
git -C "$INT010_CLONE" add VERSION
git -C "$INT010_CLONE" commit -m "bump to 100.0.0" --quiet
git -C "$INT010_CLONE" push --quiet 2>/dev/null || true

_output=$(printf 'n\n' | bash "$INT010_LOCAL/update.sh" 2>&1 || true)
echo "$_output" | grep -qi "cancel" \
  && pass "TC-INT-010c: cancelled when user declines" \
  || fail "TC-INT-010c: did not cancel"
_local_ver=$(cat "$INT010_LOCAL/VERSION" 2>/dev/null || echo "")
[ "$_local_ver" = "99.0.0" ] \
  && pass "TC-INT-010c: VERSION unchanged after declining" \
  || fail "TC-INT-010c: VERSION changed after declining (got: $_local_ver)"

echo ""

# ─────────────────────────────────────────────────────────────────────────────
echo "================================"
echo "  Integration results: $PASS passed, $FAIL failed"
echo "================================"
echo ""

[ "$FAIL" -eq 0 ]
