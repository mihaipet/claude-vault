---
name: save-memory
description: Checkpoint the current session into your vault. Updates memory.md with current state. Bonfire lit.
---

# /save-memory — Bonfire lit

Save a checkpoint. Extract what matters from this session and merge it into the vault.

---

## When to use

- **End of session** — before closing Claude Code
- **After a major decision** — lock it in before moving on
- **Natural breakpoint** — feature shipped, problem solved, phase complete

---

## Steps

1. Locate the vault (same lookup as `/load-memory`).

2. Read existing `memory.md`.

3. Review the full current conversation. Extract:
   - **Current state** — where is the project RIGHT NOW?
   - **Decisions made** — what was locked in this session?
   - **Lessons learned** — what is worth keeping?
   - **Open questions** — what is unresolved going forward?
   - **Next up** — what are the immediate next tasks?
   - **Stale items** — what in existing memory is now outdated?

4. Write an updated `memory.md` that reflects the current moment:
   - Update the `Last updated` date
   - Replace outdated state with current state
   - Merge new decisions into existing ones — do not just append
   - Remove resolved open questions; add new ones
   - Update Next up with concrete next tasks
   - Keep it under 80 lines — if it is growing, distill harder

5. If new standing rules or preferences emerged during the session, propose specific additions to `directives.md`. Show exactly what you would add. Write only after the user confirms.

6. Respond with: **"Bonfire lit, memory preserved."**

   Follow with a brief bullet list of what changed.

---

## Context Protocols

- `memory.md` — update automatically; it is your working memory
- `directives.md`, `stack.md`, `team.md`, `goals.md` — propose changes, write only on confirmation
- Capture state, not history — what is true now matters; what happened does not
- If this session was trivial (quick question, no real decisions): say so and skip the save
- Never remove content silently — note what was dropped and why
