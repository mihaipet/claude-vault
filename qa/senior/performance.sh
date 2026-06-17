#!/usr/bin/env bash
# Performance checks for claude-vault
# Covers: install speed, test suite speed, idempotency cost, subshell count, complexity
#
# Note: install.sh exits 1 in non-interactive runs (list_plugins bug with no plugins/ dir).
# Installer calls use "|| true" — timing and artifact checks are unaffected.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0; FAIL=0; WARN=0
pass() { echo "  ✓  $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗  $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ~  $1"; WARN=$((WARN+1)); }
info() { echo "  i  $1"; }

echo ""
echo "================================"
echo "  Performance Checks"
echo "================================"
echo ""

# ─── PERF-001: install.sh completes in under 10 seconds ─────────────────────
echo "PERF-001: install.sh completes in under 10 seconds"

PERF001_HOME="$(mktemp -d)"
export HOME="$PERF001_HOME"

_start=$SECONDS
printf 'Test User\nTest Project\n1\n2\n1\n1\n\nskip\n' \
  | bash "$REPO/install.sh" >/dev/null 2>&1 || true
_elapsed=$(( SECONDS - _start ))

info "install.sh took ${_elapsed}s"

if [ "$_elapsed" -lt 5 ]; then
  pass "PERF-001: install.sh completed in ${_elapsed}s (under 5s — fast)"
elif [ "$_elapsed" -lt 10 ]; then
  warn "PERF-001: install.sh completed in ${_elapsed}s (5–10s — acceptable but slow)"
  PASS=$((PASS+1))
else
  fail "PERF-001: install.sh took ${_elapsed}s — exceeds 10s threshold"
fi

echo ""

# ─── PERF-002: test suite runs in under 5 seconds ───────────────────────────
echo "PERF-002: test/run.sh completes in under 5 seconds"

if [ ! -f "$REPO/test/run.sh" ]; then
  warn "PERF-002: test/run.sh not found — skipped"
else
  PERF002_HOME="$(mktemp -d)"
  export HOME="$PERF002_HOME"

  _start=$SECONDS
  bash "$REPO/test/run.sh" >/dev/null 2>&1 || true  # allow test failures; we're timing, not auditing
  _elapsed=$(( SECONDS - _start ))

  info "test/run.sh took ${_elapsed}s"

  if [ "$_elapsed" -lt 5 ]; then
    pass "PERF-002: test suite completed in ${_elapsed}s"
  else
    fail "PERF-002: test suite took ${_elapsed}s — exceeds 5s threshold"
  fi
fi

echo ""

# ─── PERF-003: write_settings_block idempotency cost ────────────────────────
echo "PERF-003: write_settings_block — 10 consecutive calls under 2s"

PERF003_HOME="$(mktemp -d)"
export HOME="$PERF003_HOME"

# Source lib/settings.sh to get write_settings_block
# We need stub values for the directive globals it reads
source "$REPO/lib/settings.sh"

ROLE_DIRECTIVE="I am a developer. Be technically precise. Prefer code over descriptions where relevant."
LENGTH_DIRECTIVE="Be concise. Short answers. No padding, no unsolicited explanations."
CONFIRM_DIRECTIVE="Confirm before implementing. Propose first, wait for my approval."

# Set up a temp directives.md with the settings block already in it
PERF003_DIR="$(mktemp -d)"
PERF003_DIRECTIVES="$PERF003_DIR/directives.md"

cat > "$PERF003_DIRECTIVES" << 'EOF'
# Directives

<!-- vault-settings-start -->
## About me
I am a developer. Be technically precise. Prefer code over descriptions where relevant.

## Communication
- Be concise. Short answers. No padding, no unsolicited explanations.
- Confirm before implementing. Propose first, wait for my approval.
- Ask one clarifying question at a time, not a list
- If something is unclear, say so. Do not assume and proceed.
<!-- vault-settings-end -->
EOF

_start=$SECONDS
for i in $(seq 1 10); do
  write_settings_block "$PERF003_DIRECTIVES" 2>/dev/null
done
_elapsed=$(( SECONDS - _start ))

info "10x write_settings_block took ${_elapsed}s"

if [ "$_elapsed" -lt 2 ]; then
  pass "PERF-003: 10 write_settings_block calls completed in ${_elapsed}s"
else
  fail "PERF-003: 10 write_settings_block calls took ${_elapsed}s — exceeds 2s"
fi

echo ""

# ─── PERF-004: No unnecessary subshells in lib/ functions ───────────────────
echo "PERF-004: Subshell count in lib/ files"

total_subshells=0
for lib_file in "$REPO/lib"/*.sh; do
  count=$(grep -o '\$(' "$lib_file" | wc -l || true)
  name=$(basename "$lib_file")
  info "$name: $count subshell invocation(s)"
  total_subshells=$(( total_subshells + count ))
  if [ "$count" -gt 15 ]; then
    warn "PERF-004: $name has $count subshells (threshold: 15)"
  fi
done

info "Total subshells across lib/: $total_subshells"
pass "PERF-004: subshell count reported (informational)"

echo ""

# ─── PERF-005: install.sh line count (complexity proxy) ─────────────────────
echo "PERF-005: install.sh line count"

line_count=$(wc -l < "$REPO/install.sh")
info "install.sh: $line_count lines"

if [ "$line_count" -le 300 ]; then
  pass "PERF-005: install.sh is $line_count lines (under 300 threshold)"
else
  warn "PERF-005: install.sh is $line_count lines — over 300, getting complex"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
echo "================================"
echo "  Performance results: $PASS passed, $FAIL failed, $WARN warned"
echo "================================"
echo ""

[ "$FAIL" -eq 0 ]
