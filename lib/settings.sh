#!/usr/bin/env bash
# Shared settings logic — sourced by install.sh and configure.sh

ask_settings() {
  # Role
  echo "What's your role?"
  echo "  1) Designer"
  echo "  2) Developer"
  echo "  3) Product manager"
  echo "  4) Researcher"
  echo "  5) Other / skip"
  echo ""
  read -p "Enter 1-5: " ROLE_CHOICE
  echo ""

  case "$ROLE_CHOICE" in
    1) ROLE_DIRECTIVE="I am a designer. Prioritise visual thinking, component-level decisions, and design system conventions." ;;
    2) ROLE_DIRECTIVE="I am a developer. Be technically precise. Prefer code over descriptions where relevant." ;;
    3) ROLE_DIRECTIVE="I am a product manager. Structure recommendations clearly. Always flag trade-offs." ;;
    4) ROLE_DIRECTIVE="I am a researcher. Prioritise clarity, synthesis, and structured outputs." ;;
    *) ROLE_DIRECTIVE="" ;;
  esac

  # Response length
  echo "How much do you want Claude to explain?"
  echo "  1) Concise - short answers, no padding (recommended)"
  echo "  2) Detailed - explain reasoning, show the why"
  echo ""
  read -p "Enter 1 or 2: " LENGTH_CHOICE
  echo ""

  if [ "$LENGTH_CHOICE" = "2" ]; then
    LENGTH_DIRECTIVE="Explain your reasoning. I want to understand the why behind recommendations."
  else
    LENGTH_DIRECTIVE="Be concise. Short answers. No padding, no unsolicited explanations."
  fi

  # Confirmation style
  echo "How should Claude handle decisions?"
  echo "  1) Confirm first - propose before doing anything (recommended)"
  echo "  2) Proceed - flag uncertainty but keep moving"
  echo ""
  read -p "Enter 1 or 2: " CONFIRM_CHOICE
  echo ""

  if [ "$CONFIRM_CHOICE" = "2" ]; then
    CONFIRM_DIRECTIVE="Flag uncertainty but proceed. Only stop if something is destructive or irreversible."
  else
    CONFIRM_DIRECTIVE="Confirm before implementing. Propose first, wait for my approval."
  fi
}

write_settings_block() {
  local DIRECTIVES_FILE="$1"
  local TMPFILE="${DIRECTIVES_FILE}.tmp"
  local BLOCK_FILE
  BLOCK_FILE=$(mktemp)

  if [ ! -f "$DIRECTIVES_FILE" ]; then
    rm -f "$BLOCK_FILE"
    return
  fi

  # Strip existing settings block if present
  if grep -q "<!-- vault-settings-start -->" "$DIRECTIVES_FILE"; then
    awk '
      /<!-- vault-settings-start -->/{skip=1; next}
      /<!-- vault-settings-end -->/{skip=0; next}
      !skip{print}
    ' "$DIRECTIVES_FILE" > "$TMPFILE"
    mv "$TMPFILE" "$DIRECTIVES_FILE"
  fi

  # Resolve role line
  local ROLE_LINE
  if [ -n "$ROLE_DIRECTIVE" ]; then
    ROLE_LINE="$ROLE_DIRECTIVE"
  else
    ROLE_LINE="Not set. Add your role to personalise Claude responses."
  fi

  # Write settings block to temp file
  cat > "$BLOCK_FILE" << SETTINGS_EOF
<!-- vault-settings-start -->
## About me
$ROLE_LINE

## Communication
- $LENGTH_DIRECTIVE
- $CONFIRM_DIRECTIVE
- Ask one clarifying question at a time, not a list
- If something is unclear, say so. Do not assume and proceed.
<!-- vault-settings-end -->
SETTINGS_EOF

  # Inject after first line (the # Directives heading)
  {
    head -n 1 "$DIRECTIVES_FILE"
    echo ""
    cat "$BLOCK_FILE"
    echo ""
    tail -n +2 "$DIRECTIVES_FILE"
  } > "$TMPFILE"
  mv "$TMPFILE" "$DIRECTIVES_FILE"
  rm -f "$BLOCK_FILE"
}
