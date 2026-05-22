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
  read -p "Enter 1–5: " ROLE_CHOICE
  echo ""

  case "$ROLE_CHOICE" in
    1) ROLE_DIRECTIVE="I'm a designer. Prioritise visual thinking, component-level decisions, and design system conventions." ;;
    2) ROLE_DIRECTIVE="I'm a developer. Be technically precise. Prefer code over descriptions where relevant." ;;
    3) ROLE_DIRECTIVE="I'm a product manager. Structure recommendations clearly. Always flag trade-offs." ;;
    4) ROLE_DIRECTIVE="I'm a researcher. Prioritise clarity, synthesis, and structured outputs." ;;
    *) ROLE_DIRECTIVE="" ;;
  esac

  # Response length
  echo "How much do you want Claude to explain?"
  echo "  1) Concise — short answers, no padding (recommended)"
  echo "  2) Detailed — explain reasoning, show the why"
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
  echo "  1) Confirm first — propose before doing anything (recommended)"
  echo "  2) Proceed — flag uncertainty but keep moving"
  echo ""
  read -p "Enter 1 or 2: " CONFIRM_CHOICE
  echo ""

  if [ "$CONFIRM_CHOICE" = "2" ]; then
    CONFIRM_DIRECTIVE="Flag uncertainty but proceed. Only stop if something is destructive or irreversible."
  else
    CONFIRM_DIRECTIVE="Confirm before implementing — propose first, wait for my approval."
  fi
}

write_settings_block() {
  local DIRECTIVES_FILE="$1"

  local SETTINGS_BLOCK="<!-- vault-settings-start -->
## About me
${ROLE_DIRECTIVE:-Not set — add your role to personalise Claude's responses.}

## Communication
- $LENGTH_DIRECTIVE
- $CONFIRM_DIRECTIVE
- Ask one clarifying question at a time, not a list
- If something is unclear, say so — don't assume and proceed
<!-- vault-settings-end -->"

  if [ -f "$DIRECTIVES_FILE" ]; then
    if grep -q "<!-- vault-settings-start -->" "$DIRECTIVES_FILE"; then
      # Replace existing settings block
      awk '
        /<!-- vault-settings-start -->/{skip=1; next}
        /<!-- vault-settings-end -->/{skip=0; next}
        !skip{print}
      ' "$DIRECTIVES_FILE" > "$DIRECTIVES_FILE.tmp"
      mv "$DIRECTIVES_FILE.tmp" "$DIRECTIVES_FILE"
      # Inject updated block after the first line (the # Directives heading)
      awk -v block="$SETTINGS_BLOCK" '
        NR==2{print ""; print block; print ""}
        {print}
      ' "$DIRECTIVES_FILE" > "$DIRECTIVES_FILE.tmp"
      mv "$DIRECTIVES_FILE.tmp" "$DIRECTIVES_FILE"
    else
      # No settings block yet — inject after heading
      awk -v block="$SETTINGS_BLOCK" '
        NR==2{print ""; print block; print ""}
        {print}
      ' "$DIRECTIVES_FILE" > "$DIRECTIVES_FILE.tmp"
      mv "$DIRECTIVES_FILE.tmp" "$DIRECTIVES_FILE"
    fi
  fi
}
