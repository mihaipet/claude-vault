#!/usr/bin/env bash
# Vault detection and install config helpers

# Write install config to ~/.claude/.vault-install
# Args: $1=vault_path  $2=claude_md_path  $3=scope (global|project)  $4=version
#       $5=user_name (optional)  $6=project_name (optional)  $7=project_path (optional)
write_install_config() {
  local vault_path="$1"
  local claude_md="$2"
  local scope="$3"
  local version="$4"
  local user_name="${5:-}"
  local project_name="${6:-}"
  local project_path="${7:-}"
  local config_path="$HOME/.claude/.vault-install"

  mkdir -p "$(dirname "$config_path")"
  cat > "$config_path" << EOF
VAULT_PATH="$vault_path"
CLAUDE_MD="$claude_md"
SCOPE=$scope
VERSION=$version
INSTALL_DATE=$(date +%Y-%m-%d)
USER_NAME="$user_name"
PROJECT_NAME="$project_name"
PROJECT_PATH="$project_path"
EOF
}

# Detect vault location.
# Priority: 1) install config  2) well-known global path
# On success: sets VAULT_PATH and CLAUDE_MD, returns 0
# On failure: returns 1
detect_vault() {
  local config_path="$HOME/.claude/.vault-install"

  if [ -f "$config_path" ]; then
    # shellcheck source=/dev/null
    source "$config_path"
    [ -d "$VAULT_PATH" ] && return 0
  fi

  if [ -d "$HOME/.claude/vault" ]; then
    VAULT_PATH="$HOME/.claude/vault"
    CLAUDE_MD="$HOME/.claude/CLAUDE.md"
    return 0
  fi

  return 1
}
