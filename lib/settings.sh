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
  local in_about=0
  local comm_count=0

  while IFS= read -r line; do
    case "$line" in
      "<!-- vault-settings-start -->") in_block=1; continue ;;
      "<!-- vault-settings-end -->")   break ;;
    esac
    [ "$in_block" = 0 ] && continue

    # Track sections by heading
    if [[ "$line" =~ ^##\  ]]; then
      in_about=0
      if [[ "$line" = "## About me" ]]; then
        in_about=1
      fi
      continue
    fi

    # Role: first non-empty line after ## About me
    if [ "$in_about" = 1 ] && [ -n "$line" ] && [ -z "$CURRENT_ROLE_DIRECTIVE" ]; then
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

# One-time persona setup — ask for AI name and how to address the user.
# Reads USER_NAME global (already collected by install.sh).
# Sets globals: PERSONA_CHOICE ("skip"|"ai-choose"|"named"), AI_NAME, USER_PERSONA_WANTS_NAME.
# Skips silently if ~/.claude/.vault-persona already exists (never repeats).
ask_persona_setup() {
  local persona_config="$HOME/.claude/.vault-persona"
  PERSONA_CHOICE=""
  AI_NAME=""
  USER_PERSONA_WANTS_NAME=false

  if [ -f "$persona_config" ]; then
    return  # already done once — never ask again
  fi

  echo ""
  echo "────────────────────────────────"
  echo "  One-time: AI persona setup"
  echo "────────────────────────────────"
  echo ""
  echo "Would you like to give your AI assistant a name?"
  echo ""
  echo "  Type a name  → e.g. Aria, Max, Atlas"
  echo "  Press Enter  → let the AI choose its own name"
  echo "  Type 'skip'  → no name, skip this forever"
  echo ""
  read -p "Your choice: " _ai_name_raw
  echo ""

  case "$_ai_name_raw" in
    skip|SKIP)
      PERSONA_CHOICE="skip"
      ;;
    "")
      PERSONA_CHOICE="ai-choose"
      AI_NAME="choose"
      ;;
    *)
      PERSONA_CHOICE="named"
      AI_NAME="$_ai_name_raw"
      ;;
  esac

  if [ "$PERSONA_CHOICE" = "named" ] && [ -n "${USER_NAME:-}" ]; then
    echo "Should the AI address you as \"$USER_NAME\"?"
    read -p "Press Enter to confirm, type a nickname, or type 'skip': " _user_name_pref
    echo ""
    case "$_user_name_pref" in
      skip|SKIP) ;;
      "")
        USER_PERSONA_WANTS_NAME=true
        ;;
      *)
        USER_PERSONA_WANTS_NAME=true
        USER_NAME="$_user_name_pref"
        ;;
    esac
  fi

  # Write persona config — marks this as done forever
  mkdir -p "$(dirname "$persona_config")"
  {
    echo "PERSONA_SETUP=$PERSONA_CHOICE"
    [ -n "$AI_NAME" ] && echo "AI_NAME=$AI_NAME"
    [ "$USER_PERSONA_WANTS_NAME" = "true" ] && echo "USER_PERSONA_NAME=$USER_NAME"
  } > "$persona_config"
}

# Write the persona identity block to directives.md.
# Reads globals: PERSONA_CHOICE, AI_NAME, USER_NAME, USER_PERSONA_WANTS_NAME.
# No-ops if PERSONA_CHOICE is empty (setup was already done in a prior install).
write_persona_block() {
  local directives_file="$1"
  [ -f "$directives_file" ] || return 0
  [ -n "$PERSONA_CHOICE" ] || return 0

  case "$PERSONA_CHOICE" in
    skip) return ;;

    ai-choose)
      cat >> "$directives_file" << 'PERSONA_EOF'

<!-- vault-persona-start -->
## Identity
You have not been given a name yet. At the very start of your next session with this vault:
1. Introduce yourself briefly.
2. Suggest a creative name for yourself that fits the project context.
3. Update this block in directives.md — replace everything between the vault-persona markers with:
   `## Identity`
   `Your name is [the name you chose].`
<!-- vault-persona-end -->
PERSONA_EOF
      ;;

    named)
      local user_line=""
      [ "$USER_PERSONA_WANTS_NAME" = "true" ] && user_line=" Address the user as $USER_NAME."
      {
        echo ""
        echo "<!-- vault-persona-start -->"
        echo "## Identity"
        echo "Your name is $AI_NAME.$user_line"
        echo "<!-- vault-persona-end -->"
      } >> "$directives_file"
      ;;
  esac
}
