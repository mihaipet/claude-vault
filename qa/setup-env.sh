#!/usr/bin/env bash
# Source this file (don't run it) to set up an isolated QA environment.
# Usage: source qa/setup-env.sh
#
# Sets $HOME to a fresh temp directory so install.sh, configure.sh, and
# uninstall.sh never touch your real ~/.claude or vault files.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: source this file, don't run it directly."
  echo "  source qa/setup-env.sh"
  exit 1
fi

QA_HOME=$(mktemp -d /tmp/claude-vault-qa-XXXXXX)
export QA_HOME
export HOME="$QA_HOME"
export VAULT_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "┌─────────────────────────────────────────┐"
echo "│  Claude Vault QA Environment Active     │"
echo "└─────────────────────────────────────────┘"
echo ""
echo "  Fake HOME : $QA_HOME"
echo "  Vault repo: $VAULT_REPO"
echo ""
echo "  Your real ~/.claude is untouched."
echo "  Run 'bash qa/teardown.sh' to clean up."
echo ""
