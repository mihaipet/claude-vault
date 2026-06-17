---
name: load-memory
description: Reload all vault files mid-session to refresh your context. Use when starting a new task or returning after a break.
---

# /load-memory — I know kung fu

Perform a full vault reload. Read every vault file and internalize it before continuing.

---

## When to use

- **Start of a new task** — full context before diving in
- **Mid-session refresh** — vault was updated and you want it now
- **Context drift** — conversation has wandered; reset to what actually matters

---

## Steps

1. Locate the vault. Check CLAUDE.md for the vault path, or look in:
   - `~/.claude/vault/`
   - `vault/` inside the current project directory

2. Read every vault file that exists — in this order:
   - `memory.md` (required — current project state)
   - `directives.md` (required — standing rules)
   - `stack.md`, `team.md`, `goals.md` (if present)
   - Any other `.md` files in the vault folder

3. Apply the directives immediately. They are active from this moment.

4. Respond with: **"I know kung fu."**

   Follow with a single short paragraph:
   - What project you're in and where things stand
   - Current focus
   - One or two active constraints you'll honour

---

## Rules

- Never modify any files
- If vault is not found: say so clearly and suggest running `./install.sh` or `/setup`
- If a file is missing: note it but continue with what's available
- Keep the response brief — this is a sync, not a report
