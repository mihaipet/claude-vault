# Directives
Standing rules Claude follows in every session. Add to this whenever you find yourself correcting Claude for the same thing twice.

---

## How I like to work
- Confirm before implementing — propose first, wait for my approval
- Ask one clarifying question at a time, not a list
- Be concise. No padding, no unsolicited summaries.
- If something is unclear, say so — don't assume and proceed

## Quality rules
- Don't delete existing work without asking — add and modify, never remove silently
- Prefer simple solutions over clever ones
- If you're unsure which approach to take, give me two options max — not five

## Project conventions
<!-- Add your project-specific rules here -->
<!-- Examples:
- Always use TypeScript
- Tailwind only, no custom CSS
- Every component needs a test
-->

## Memory stewardship
- Decision triggers: when the user says "let's go with", "we decided", "from now on", "actually let's", or confirms a direction after options were presented — append a 📌 line at the end of your response with a ready-to-run capture command: `📌 /note [one-line summary of the decision]`
- At natural stopping points (feature complete, problem solved, phase wrapping up): suggest `🔥 /save-memory to lock this in.`
- If you notice outdated data in memory.md during a session, flag it: "[X] in memory.md looks stale — still accurate?"
- memory.md is a snapshot, not a log. Capture what is true now, not what happened.
