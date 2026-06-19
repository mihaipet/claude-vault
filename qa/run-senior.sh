#!/usr/bin/env bash
# Master runner for the senior automated QA suite.
# Runs all checks in sequence and prints a final summary.
#
# Usage: bash qa/run-senior.sh (from repo root, with QA env active)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0

run_check() {
  local label="$1"
  local script="$2"

  echo ""
  echo "════════════════════════════════════════════════"
  echo "  $label"
  echo "════════════════════════════════════════════════"

  # Run the check script, capture its exit code
  if bash "$REPO_DIR/$script" 2>&1; then
    :
  else
    echo ""
    echo "  [suite exited with error]"
  fi
}

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     Claude Vault — Senior QA Suite           ║"
echo "╚══════════════════════════════════════════════╝"

if [ -z "$QA_HOME" ]; then
  echo ""
  echo "WARNING: QA_HOME not set. Run 'source qa/setup-env.sh' first."
  echo "Continuing but installs will use your real HOME."
  echo ""
fi

run_check "0 — Regression (existing test suite)"  "test/run.sh"
run_check "1 — Security audit"                    "qa/senior/security.sh"
run_check "2 — Architecture review"               "qa/senior/architecture.sh"
run_check "3 — Integration tests"                 "qa/senior/integration.sh"
run_check "4 — Performance checks"                "qa/senior/performance.sh"

echo ""
echo "════════════════════════════════════════════════"
echo "  Senior QA suite complete."
echo "  Review findings above. Bugs marked [BUG],"
echo "  security issues marked [SEC], warnings [WARN]."
echo "════════════════════════════════════════════════"
echo ""
