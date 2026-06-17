# Claude Vault v2.0.0 — Test Handoff

**For the next agent:** Deliver tests ONE AT A TIME. After each test, wait for the user to say "pass", "fail", or "done" before moving to the next. Do not dump the whole list. Be patient — the user hates testing and you are here to make it easy.

---

## Current state

- **Version:** 2.0.0
- **Branch:** `claude/vault-memory-setup-wybex3` (NOT yet merged to main)
- **Repo:** `mihaipet/claude-vault`
- **Automated tests:** 49/49 passing — integration, regression, security, architecture all green

**What's left:** 12 manual tests that require a live Claude Code session (skills + triggers). These cannot be automated. The user runs them; you guide one at a time.

**After all tests pass:** merge `claude/vault-memory-setup-wybex3` → `main`. That's when anyone downloading the repo gets v2.0.0.

**Known deferred issues (do NOT fix now — user said "we'll return"):**
- SEC-001: `&` in user name corrupts memory.md via sed injection
- SEC-002: PROJECT_PATH not canonicalised (path traversal risk)
- ARCH-002: uninstall.sh uses hardcoded marker strings instead of constants

---

## Setup (do this once before any tests)

Tell the user to run this in a terminal. Then do a real install into their actual `~/.claude`:

```bash
cd /path/to/claude-vault   # wherever they cloned it
bash install.sh
```

At the prompts:
- Name: their real name
- Project: whatever they're working on
- Scope: `1` (Global)
- Role: their choice
- Length: their choice
- Decisions: their choice
- Extra files: skip (Enter)
- Persona / AI name: their choice

After install, open Claude Code (`claude` in terminal) and keep it open for all skill + trigger tests.

---

## Test queue

Deliver each test below in order. One at a time.

---

### TEST 1 — /load-memory (fresh vault)

**In Claude Code, type:** `/load-memory`

**What to look for:**
- First line of Claude's response is exactly: `🧠 I know kung fu.`
- Claude follows with a short paragraph mentioning the project name and current focus
- No error about vault not found
- Claude does NOT ask questions

**Tell me:** pass or fail?

---

### TEST 2 — /load-memory (mid-session refresh)

**Steps:**
1. In Claude Code, have 3 back-and-forth exchanges about something unrelated — ask Claude to explain HTTP caching or something random
2. Then type: `/load-memory`

**What to look for:**
- Claude responds with `🧠 I know kung fu.` regardless of the previous topic
- Claude re-anchors to the vault (mentions the project, not HTTP caching)
- Clean context switch — no mixing

**Tell me:** pass or fail?

---

### TEST 3 — /save-memory (basic checkpoint)

**Steps:**
1. In Claude Code, make a concrete decision in the conversation:
   - You: "Should we use SQLite or Postgres?"
   - Claude: (responds)
   - You: "Let's go with Postgres — we'll need concurrency later"
2. Type: `/save-memory`
3. In a separate terminal: `cat ~/.claude/vault/memory.md`

**What to look for:**
- Claude responds with `🔥 Bonfire lit, memory preserved.` as the first line
- Claude lists what changed (should mention Postgres)
- `memory.md` "Last updated" is today's date
- `memory.md` has a line about the Postgres decision

**Tell me:** pass or fail?

---

### TEST 4 — /note with inline text

**In Claude Code, type exactly:** `/note using Tailwind for all styling — no CSS modules`

**What to look for:**
- Claude responds with `📌 Noted.` as the first line
- Claude shows what was added and which section it went in
- In a terminal: `cat ~/.claude/vault/memory.md` — find the Tailwind line
- No other existing lines in memory.md were changed

**Tell me:** pass or fail?

---

### TEST 5 — /note without text (Claude infers)

**Steps:**
1. In Claude Code, have a short conversation with a clear decision:
   - You: "Monorepo or separate repos?"
   - Claude: (responds)
   - You: "Let's go monorepo — easier to keep packages in sync"
2. Then type just: `/note` (nothing after it)

**What to look for:**
- Claude surfaces a confirmation prompt: "Should I note: [one-line summary]?" — it does NOT silently write
- After you say yes, Claude responds with `📌 Noted.`
- `memory.md` has a new line about the monorepo decision

**Tell me:** pass or fail?

---

### TEST 6 — /vault-edit

**Steps:**
1. In Claude Code, type: `/vault-edit`
2. Say: "Update the 'Current focus' section in memory.md — I'm now working on the authentication flow"
3. Read Claude's proposal
4. If Claude shows a diff, type `yes`

**What to look for:**
- Claude shows the current value of "Current focus" before proposing a change
- Claude proposes an update with a before/after diff
- Claude WAITS for confirmation before writing
- After confirmation, check `cat ~/.claude/vault/memory.md` — "Current focus" shows the auth flow
- No other sections were silently changed

**Tell me:** pass or fail?

---

### TEST 7 — /setup (change a setting in-session)

**Steps:**
1. In Claude Code, type: `/setup`
2. Say: "Change my response style to detailed"
3. Read Claude's proposal
4. Type `yes`

**What to look for:**
- Claude shows the current setting before proposing the change
- Claude proposes replacing it with the detailed variant
- Claude shows a diff (before/after)
- After confirmation: `grep -A10 'vault-settings-start' ~/.claude/vault/directives.md` — shows the detailed length directive
- The rest of directives.md (your personal notes, etc.) is unchanged

**Tell me:** pass or fail?

---

### TEST 8 — "let's go with" trigger

**In Claude Code, type:**
> I've been evaluating React vs Vue. Let's go with React — it has better ecosystem support for what we need.

**What to look for:**
- At or near the end of Claude's response: `📌 /note using React — better ecosystem support`
- It's a ready-to-run command, not just a description
- The 📌 is the last (or near-last) thing in the response

**Tell me:** pass or fail?

---

### TEST 9 — "we decided" trigger

**In Claude Code, type:**
> We decided to use a monorepo structure — it keeps shared types in one place and avoids versioning headaches.

**What to look for:**
- Claude's response includes a `📌 /note ...` suggestion at the end
- The note captures the monorepo decision in one line

**Tell me:** pass or fail?

---

### TEST 10 — "from now on" trigger

**In Claude Code, type:**
> From now on always use async/await, never .then() chains. It's a hard rule for this codebase.

**What to look for:**
- Claude includes a `📌 /note ...` suggestion at the end
- Bonus (higher-quality behaviour): Claude suggests adding it to `directives.md` instead of `memory.md` because it's a standing rule — both are acceptable, but directives.md is better

**Tell me:** pass or fail? (If Claude only notes to memory.md, say "partial pass")

---

### TEST 11 — Natural stopping point trigger

**In Claude Code, type:**
> The authentication flow is done. Login, logout, JWT refresh, and the protected routes are all working and tested.

**What to look for:**
- At or near the end of Claude's response: `🔥 /save-memory to lock this in.`
- It's a ready-to-run command, not just a description

**Tell me:** pass or fail?

---

### TEST 12 — Stale data flag

**Steps:**
1. In a terminal: `echo "- Using React 17 (legacy class components)" >> ~/.claude/vault/memory.md`
2. Start a NEW Claude Code session: `claude` (not the existing one)
3. Type: `/load-memory`
4. After Claude loads the vault, type: "What version of React are we using?"

**What to look for:**
- Claude loads the vault including the React 17 line
- When asked about React version, Claude flags it as potentially stale: something like "[React 17] looks stale — still accurate?" or similar
- Claude does NOT confidently assert "You're using React 17" without any hedging
- Clean up after: remove the stale line from memory.md

**Tell me:** pass or fail?

---

## After all 12 tests pass

Tell the agent: "merge to main"

The agent will:
1. Create a PR from `claude/vault-memory-setup-wybex3` → `main`
2. Or ask if you want a direct merge

Once merged, anyone downloading the repo gets v2.0.0.

---

## If tests fail

Note which test ID failed and what happened. The agent will investigate and fix, then re-run the failed test before continuing.

Known issues that will cause test failures but are DEFERRED:
- If you enter `&` or `/` in your name during install → SEC-001 (skip this for now)
- If you enter a path with `..` during project-scoped install → SEC-002 (skip)

These are documented and intentionally deferred to the next fix cycle.
