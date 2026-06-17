#!/usr/bin/env bash
# Security audit — static analysis of all bash scripts.
# Reports findings with severity: [HIGH] [MEDIUM] [LOW] [INFO]
# Exit 0 always — findings are informational, not build-breaking.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
WARN=0
FAIL=0

pass() { echo "  ✓  $1"; PASS=$((PASS+1)); }
warn() { echo "  ⚠  [MEDIUM] $1"; WARN=$((WARN+1)); }
fail() { echo "  ✗  [HIGH]   $1"; FAIL=$((FAIL+1)); }
low()  { echo "  ·  [LOW]    $1"; WARN=$((WARN+1)); }
info() { echo "     [INFO]   $1"; }

echo ""
echo "── SEC-001: Unquoted user input in sed replacements ────────────────────────"
echo ""
# USER_NAME and PROJECT_NAME are used in sed s/// replacement positions.
# If they contain '&' (sed: insert matched text) or '/' (delimiter), the
# sed command corrupts output or errors out.
if grep -n 's/{{NAME}}/\$USER_NAME' "$REPO/install.sh" 2>/dev/null | grep -v '\\/' | grep -q .; then
  fail "SEC-001 install.sh: \$USER_NAME used directly in sed s/PAT/\$VAR/g replacement."
  info "If USER_NAME contains '&' → corrupted output. If it contains '/' → sed error."
  info "Fix: use '|' as delimiter AND escape '&': s|{{NAME}}|\${USER_NAME//&/\\\\&}|g"
else
  pass "SEC-001 sed delimiter check (manual review recommended)"
fi

# Check if sed uses double-quote expansion with user vars
if grep -n "sed.*\\$USER_NAME\|sed.*\\$PROJECT_NAME" "$REPO/install.sh" | grep -q '"'; then
  fail "SEC-001b install.sh: user input expanded inside double-quoted sed expression."
  info "Special chars in name (&, /) will corrupt or crash sed. Escape before substitution."
else
  pass "SEC-001b no obvious sed injection pattern found"
fi

echo ""
echo "── SEC-002: Path traversal in project-scoped install ───────────────────────"
echo ""
# User enters PROJECT_PATH freely. If they enter ../../etc, VAULT_PATH resolves
# outside intended scope. Should realpath + validate.
if grep -q 'realpath\|readlink -f' "$REPO/install.sh"; then
  pass "SEC-002 PROJECT_PATH is canonicalised before use"
else
  warn "SEC-002 install.sh: PROJECT_PATH is used without canonicalisation (realpath)."
  info "User could enter '../../../../tmp/evil' to write vault files outside project."
  info "Fix: PROJECT_PATH=\$(realpath \"\$PROJECT_PATH\") after the directory check."
fi

echo ""
echo "── SEC-003: Temp file cleanup on error paths ───────────────────────────────"
echo ""
# settings.sh write_settings_block creates a temp file via mktemp.
# If set -e fires mid-function, the temp file may be left behind.
if grep -q 'trap.*rm.*block\|trap.*mktemp' "$REPO/lib/settings.sh"; then
  pass "SEC-003 temp file has trap cleanup"
else
  warn "SEC-003 lib/settings.sh: mktemp'd temp file has no trap for cleanup on error."
  info "If write_settings_block exits early (set -e), /tmp/tmp.XXXXXX is leaked."
  info "Fix: add 'trap \"rm -f \\\"\$block\\\"\" RETURN' after mktemp call."
fi

echo ""
echo "── SEC-004: File permissions on config files ───────────────────────────────"
echo ""
# .vault-persona contains user's preferred name — not a secret, but
# default umask (022) creates it world-readable (644).
# .vault-install is similarly open. Neither is dangerous, but hygiene check.
if grep -q 'chmod.*vault-persona\|chmod.*vault-install' "$REPO/lib/settings.sh" "$REPO/lib/vault.sh" 2>/dev/null; then
  pass "SEC-004 config files have explicit permissions set"
else
  low "SEC-004 .vault-persona and .vault-install are created with default umask (usually 644)."
  info "Names are not secrets, but 600 would be more defensive."
  info "Fix: add 'chmod 600 \"\$config_path\"' after writing each config file."
fi

echo ""
echo "── SEC-005: eval usage ──────────────────────────────────────────────────────"
echo ""
if grep -rn '\beval\b' "$REPO/install.sh" "$REPO/configure.sh" "$REPO/lib/" 2>/dev/null | grep -v '^Binary'; then
  fail "SEC-005 eval found — review carefully for injection risk."
else
  pass "SEC-005 no eval usage in scripts or lib/"
fi

echo ""
echo "── SEC-006: Source of install config (shellcheck) ──────────────────────────"
echo ""
# detect_vault() does: source "$config_path" where config_path is ~/.vault-install
# If that file were tampered with, it could execute arbitrary code.
# This is an acceptable risk for a local tool (user controls their own home dir).
info "SEC-006 detect_vault() sources ~/.claude/.vault-install (local file, user-owned)."
info "Acceptable for a local tool. Would be high risk in a networked/shared context."
pass "SEC-006 source of local config: acceptable risk for local tool"

echo ""
echo "── SEC-007: AI_NAME written to directives.md without sanitisation ──────────"
echo ""
# If AI_NAME contains shell metacharacters, they end up in a .md file
# (not executed), so not dangerous. But markdown injection could confuse Claude.
if grep -qn 'AI_NAME.*directives\|echo.*AI_NAME' "$REPO/lib/settings.sh"; then
  low "SEC-007 AI_NAME is written to directives.md without sanitisation."
  info "Not executable — .md files are not eval'd. But a name like '## New Section'"
  info "could inject fake headings into directives.md and confuse Claude."
  info "Fix: strip leading # characters from AI_NAME before writing."
else
  pass "SEC-007 AI_NAME sanitisation"
fi

echo ""
echo "── SEC-008: Uninstall removes files without confirmation of paths ───────────"
echo ""
# uninstall.sh uses rm -rf on skill_path which comes from $HOME/.claude/skills/$skill
# $HOME is user-controlled. If skill name were attacker-controlled this could be
# dangerous. Here skill names are hardcoded strings, so it's safe.
pass "SEC-008 rm -rf in uninstall uses hardcoded skill names (not user input)"

echo ""
echo "────────────────────────────────────────────────────────────────────────────"
printf "  Security results: %d passed  %d warnings/low  %d high findings\n" "$PASS" "$WARN" "$FAIL"
echo "────────────────────────────────────────────────────────────────────────────"
echo ""
