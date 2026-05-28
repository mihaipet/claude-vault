---
name: setup
description: Use to review or change vault settings — role, response style, confirmation behaviour — without leaving Claude Code.
---

# /setup — Review and change your vault settings

Use this skill to review your current configuration and update any settings without leaving Claude Code.

---

## What you can change

- **Role** — how Claude calibrates its responses to your work
- **Response length** — concise vs detailed
- **Confirmation style** — confirm before every action, or proceed and flag uncertainty
- **Vault files** — which files Claude loads, and what's in them

---

## How to use

Tell Claude what you want to change:

> "Show me my current settings"
> "Change my response style to detailed"
> "I want Claude to confirm before doing anything"
> "Update my role to developer"

Claude will show you the current value, propose the change, and update `directives.md` when you confirm.

---

## Rules for this skill

- Always show the current value before proposing a change
- Show a before/after diff for any edit to directives.md
- Never change memory.md during a settings session — that's for /vault-edit
- After updating, tell the user when the change takes effect (next session)
- If the user asks to see all settings, read directives.md and summarise clearly

---

## Settings reference

| Setting | Where it lives | How to change |
|---|---|---|
| Role | directives.md → About me | Edit the first line of that section |
| Response length | directives.md → Communication | First bullet |
| Confirmation style | directives.md → Communication | Second bullet |
| Vault file list | CLAUDE.md → Vault section | Add/remove file references |
| Project conventions | directives.md → Project conventions | Free-form, user owns this |
