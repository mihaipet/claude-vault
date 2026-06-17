---
name: note
description: Quickly capture a single decision, rule, or insight to memory.md. Lightweight mid-session capture — no full checkpoint needed.
---

# /note — Quick capture

Capture one thing to memory right now.

---

## Usage

```
/note using Postgres for the database
/note never use CSS modules — Tailwind only
/note API rate limit is 100 req/min per user
```

Or run `/note` alone and Claude will surface the most recent decision from the conversation for confirmation.

---

## Steps

1. Identify what to note:
   - If text was provided after `/note`, use that verbatim
   - If no text: scan the last few exchanges, identify the most recent decision or rule, and propose it: "Should I note: [one-line summary]?"

2. Locate the vault. Read `memory.md`.

3. Append the note to the most appropriate section:
   - A decision or direction chosen → **Recent decisions**
   - A rule, preference, or constraint → propose adding to `directives.md` instead and ask first
   - A fact, lesson, or discovery → **Lessons learned**
   - A task or next step → **Next up**

4. Write one line only. Do not rewrite existing content.

5. Respond with: **"📌 Noted."** and show exactly what was added and where.

---

## Rules

- One note per `/note` call — do not batch multiple items
- Never rewrite or remove existing content, only append
- If the target section is missing from memory.md, add the note under the closest existing section
- If the note belongs in directives.md rather than memory.md, say so and ask before writing
