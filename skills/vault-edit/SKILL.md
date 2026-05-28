---
name: vault-edit
description: Use at end of session, when adding a new rule, or creating a new vault file. Maintains and grows your persistent context files.
---

# /vault-edit — Grow your second brain

Use this skill to maintain and expand your vault — the persistent context files Claude reads every session.

---

## When to use

- **End of session** — update `memory.md` with what happened, what was decided, what to pick up next
- **New rule or preference** — add it to `directives.md` so Claude follows it from now on
- **New knowledge area** — create a new vault file for a topic that doesn't fit anywhere yet
- **Cleanup** — trim stale entries from `memory.md`, consolidate `directives.md`

---

## The two core files

### memory.md
A living distillation of your project state. Not a log — a snapshot.
Keep it short. If it grows past 100 lines, trim it.

Update after every session:
- What are you focused on right now?
- What decisions were made?
- What should the next session know?

### directives.md
Standing rules Claude follows in every session.
If you find yourself correcting Claude for the same thing twice — add it here.

---

## Creating a new vault file

Only create a new file when the topic is:
1. Distinct enough that it won't fit in memory or directives
2. Something you'll want to load in multiple future sessions

Name it clearly: `research-notes.md`, `team.md`, `api-reference.md`.
Keep one clear topic per file.

---

## Rules for this skill

- Never delete vault content without asking first — archive it instead
- Suggest edits, don't overwrite — show the before/after
- Keep entries short. A vault entry that needs a paragraph to explain itself needs to be rewritten, not expanded
- After every update, confirm what changed and why
