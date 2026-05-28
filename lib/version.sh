#!/usr/bin/env bash
# Version constant — sourced by all scripts
# BASH_SOURCE resolves path relative to this file, not the calling script

VAULT_VERSION="$(cat "$(dirname "${BASH_SOURCE[0]}")/../VERSION")"

VAULT_SETTINGS_START="<!-- vault-settings-start -->"
VAULT_SETTINGS_END="<!-- vault-settings-end -->"
VAULT_CLAUDE_START="<!-- claude-vault-start -->"
VAULT_CLAUDE_END="<!-- claude-vault-end -->"
