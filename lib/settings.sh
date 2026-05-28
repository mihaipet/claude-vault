#!/usr/bin/env bash
# Shared settings logic — sourced by install.sh and configure.sh

# Read current settings from an existing directives.md.
# Sets: CURRENT_ROLE_DIRECTIVE, CURRENT_LENGTH_DIRECTIVE, CURRENT_CONFIRM_DIRECTIVE
# Returns with empty strings if file missing or no settings block found.
read_current_settings() {
  local directives_file="$1"
  CURRENT_ROLE_DIRECTIVE=""
  CURRENT_LENGTH_DIRECTIVE=""
  CURRENT_CONFIRM_DIRECTIVE=""

  [ -f "$directives_file" ] || return

  local in_block=0
  local comm_count=0

  while IFS= read -r line; do
    case "$line" in
      "<!-- vault-settings-start -->") in_block=1; continue ;;
      "<!-- vault-settings-end -->")   break ;;
    esac
    [ "$in_block" = 0 ] && continue

    # Role: non-empty content line after ## About me
    if [[ "$line" =~ ^(I\ am\ a|Not\ set) ]]; then
      CURRENT_ROLE_DIRECTIVE="$line"
    fi

    # Communication bullets — first two only
    if [[ "$line" =~ ^-\  ]] && [ "$comm_count" -lt 2 ]; then
      comm_count=$((comm_count + 1))
      local value="${line#- }"
      if [ "$comm_count" = 1 ]; then
        CURRENT_LENGTH_DIRECTIVE="$value"
      else
        CURRENT_CONFIRM_DIRECTIVE="$value"
      fi
    fi
  done < "$directives_file"
}

# Prompt for role, response length, and confirmation style.
# Optional arg: path to existing directives.md — shows current values before each prompt.
ask_settings() {
  local directives_file="${1:-}"
  [ -n "$directives_file" ] && read_current_settings "$directives_file"

  # ── Role ────────────────────────────────────────────────────────────────────
  echo "What's your role?"
  echo "  1) Designer"
  echo "  2) Developer"
  echo "  3) Product manager"
  echo "  4) Researcher"
  echo "  5) Other / skip"
  [ -n "$CURRENT_ROLE_DIRECTIVE" ] && echo "" && echo "  Current: $CURRENT_ROLE_DIRECTIVE"
  echo ""
  read -p "Enter 1–5 (or press Enter to keep current): " ROLE_CHOICE
  echo ""

  case "$ROLE_CHOICE" in
    1) ROLE_DIRECTIVE="I am a designer. Prioritise visual thinking, component-level decisions, and design system conventions." ;;
    2) ROLE_DIRECTIVE="I am a developer. Be technically precise. Prefer code over descriptions where relevant." ;;
    3) ROLE_DIRECTIVE="I am a product manager. Structure recommendations clearly. Always flag trade-offs." ;;
    4) ROLE_DIRECTIVE="I am a researcher. Prioritise clarity, synthesis, and structured outputs." ;;
    "") ROLE_DIRECTIVE="${CURRENT_ROLE_DIRECTIVE:-}" ;;
    *) ROLE_DIRECTIVE="" ;;
  esac

  # ── Response length ──────────────────────────────────────────────────────────
  echo "How much do you want Claude to explain?"
  echo "  1) Concise — short answers, no padding (recommended)"
  echo "  2) Detailed — explain reasoning, show the why"
  [ -n "$CURRENT_LENGTH_DIRECTIVE" ] && echo "" && echo "  Current: $CURRENT_LENGTH_DIRECTIVE"
  echo ""
  read -p "Enter 1 or 2 (or press Enter to keep current): " LENGTH_CHOICE
  echo ""

  case "$LENGTH_CHOICE" in
    1) LENGTH_DIRECTIVE="Be concise. Short answers. No padding, no unsolicited explanations." ;;
    2) LENGTH_DIRECTIVE="Explain your reasoning. I want to understand the why behind recommendations." ;;
    "") LENGTH_DIRECTIVE="${CURRENT_LENGTH_DIRECTIVE:-Be concise. Short answers. No padding, no unsolicited explanations.}" ;;
    *) LENGTH_DIRECTIVE="Be concise. Short answers. No padding, no unsolicited explanations." ;;
  esac

  # ── Confirmation style ───────────────────────────────────────────────────────
  echo "How should Claude handle decisions?"
  echo "  1) Confirm first — propose before doing anything (recommended)"
  echo "  2) Proceed — flag uncertainty but keep moving"
  [ -n "$CURRENT_CONFIRM_DIRECTIVE" ] && echo "" && echo "  Current: $CURRENT_CONFIRM_DIRECTIVE"
  echo ""
  read -p "Enter 1 or 2 (or press Enter to keep current): " CONFIRM_CHOICE
  echo ""

  case "$CONFIRM_CHOICE" in
    1) CONFIRM_DIRECTIVE="Confirm before implementing. Propose first, wait for my approval." ;;
    2) CONFIRM_DIRECTIVE="Flag uncertainty but proceed. Only stop if something is destructive or irreversible." ;;
    "") CONFIRM_DIRECTIVE="${CURRENT_CONFIRM_DIRECTIVE:-Confirm before implementing. Propose first, wait for my approval.}" ;;
    *) CONFIRM_DIRECTIVE="Confirm before implementing. Propose first, wait for my approval." ;;
  esac
}

# Write (or replace) the managed settings block in directives.md.
# Only the block between vault-settings markers is touched. User content is preserved.
write_settings_block() {
  local directives_file="$1"
  local tmpfile="${directives_file}.tmp"
  local block
  block=$(mktemp)

  [ -f "$directives_file" ] || { rm -f "$block"; return; }

  # Strip existing settings block — only the managed region, nothing else
  if grep -q "<!-- vault-settings-start -->" "$directives_file"; then
    awk '
      /<!-- vault-settings-start -->/{skip=1; next}
      /<!-- vault-settings-end -->/{skip=0; next}
      !skip{print}
    ' "$directives_file" > "$tmpfile"
    mv "$tmpfile" "$directives_file"
  fi

  local role_line
  if [ -n "$ROLE_DIRECTIVE" ]; then
    role_line="$ROLE_DIRECTIVE"
  else
    role_line="Not set. Add your role to personalise Claude responses."
  fi

  cat > "$block" << BLOCK_EOF
<!-- vault-settings-start -->
## About me
$role_line

## Communication
- $LENGTH_DIRECTIVE
- $CONFIRM_DIRECTIVE
- Ask one clarifying question at a time, not a list
- If something is unclear, say so. Do not assume and proceed.
<!-- vault-settings-end -->
BLOCK_EOF

  # Find the # Directives heading by content, not by line number (fragility fix)
  local heading_line
  heading_line=$(grep -n "^# Directives" "$directives_file" | head -1 | cut -d: -f1)

  if [ -n "$heading_line" ]; then
    {
      head -n "$heading_line" "$directives_file"
      echo ""
      cat "$block"
      echo ""
      tail -n +"$((heading_line + 1))" "$directives_file"
    } > "$tmpfile"
    mv "$tmpfile" "$directives_file"
  else
    # No heading — prepend block
    { cat "$block"; echo ""; cat "$directives_file"; } > "$tmpfile"
    mv "$tmpfile" "$directives_file"
  fi

  rm -f "$block"
}
