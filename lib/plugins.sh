#!/usr/bin/env bash
# Plugin discovery and installation helpers

# List available plugins from a plugins directory.
# Outputs one plugin directory name per line.
# Only includes directories that contain a manifest.sh.
list_plugins() {
  local plugins_dir="$1"
  [ -d "$plugins_dir" ] || return

  for dir in "$plugins_dir"/*/; do
    [ -f "${dir}manifest.sh" ] && basename "$dir"
  done
}

# Load plugin manifest variables into current environment.
# Sets: PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_DESCRIPTION, PLUGIN_MIN_VAULT_VERSION
load_plugin_manifest() {
  local plugin_dir="${1%/}/"
  [ -f "${plugin_dir}manifest.sh" ] || { echo "ERROR: no manifest.sh in $plugin_dir" >&2; return 1; }
  # shellcheck source=/dev/null
  source "${plugin_dir}manifest.sh"
}

# Install a single plugin.
# Args: $1=plugin_dir  $2=vault_path  $3=skills_dest
# Non-destructive: never overwrites existing vault files.
install_plugin() {
  local plugin_dir="$1"
  local vault_path="$2"
  local skills_dest="$3"

  load_plugin_manifest "$plugin_dir"
  echo "Installing plugin: $PLUGIN_NAME"

  # Install skills — always overwritten (skills are plugin-owned; vault files are user-owned)
  if [ -d "${plugin_dir}skills" ]; then
    for skill_dir in "${plugin_dir}skills"/*/; do
      [ -d "$skill_dir" ] || continue
      local skill_name
      skill_name=$(basename "$skill_dir")
      mkdir -p "$skills_dest/$skill_name"
      cp "${skill_dir}SKILL.md" "$skills_dest/$skill_name/SKILL.md"
      echo "  ✓ Skill installed: /$skill_name"
    done
  fi

  # Install templates — only if not already present
  if [ -d "${plugin_dir}templates" ]; then
    for template in "${plugin_dir}templates"/*.md; do
      [ -f "$template" ] || continue
      local filename
      filename=$(basename "$template")
      if [ ! -f "$vault_path/$filename" ]; then
        cp "$template" "$vault_path/$filename"
        echo "  ✓ Vault file created: $filename"
      else
        echo "  ✓ $filename already exists — skipped"
      fi
    done
  fi

  # Run plugin's custom install hook if present
  if [ -f "${plugin_dir}install.sh" ]; then
    # shellcheck source=/dev/null
    source "${plugin_dir}install.sh"
  fi
}
