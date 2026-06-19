# Claude Vault — Manual Test Cases

## What you're testing

Claude Vault is a bash installer that sets up a "second brain" for Claude Code (Anthropic's AI CLI). It installs a set of persistent context files that Claude reads every session, plus five slash command skills that let you save and recall project state from inside Claude Code.

The files it installs:
- `~/.claude/CLAUDE.md` — tells Claude where to find the vault and what skills are available
- `~/.claude/vault/memory.md` — a snapshot of the current project state
- `~/.claude/vault/directives.md` — standing rules Claude follows every session
- `~/.claude/.vault-install` — records where the vault lives (scope, paths, version)
- `~/.claude/.vault-persona` — records the one-time AI name choice (never re-asked)

The five skills are slash commands you type inside a Claude Code session:
- `/load-memory` — reload vault context mid-session
- `/save-memory` — checkpoint the current session to vault
- `/note` — capture a single decision inline
- `/vault-edit` — browse and edit vault files directly
- `/setup` — change settings (role, verbosity, confirmation style)

## Two kinds of tests

**Automated tests** live in `qa/senior/` and `qa/fixtures/` and run via `bash qa/run-senior.sh`. They check static properties: file structure, sed-injection risks, settings block format, install config keys. Run these first — they catch many regressions in under a minute.

**Manual tests (this file)** require human judgment, a real shell, and for the Skills/Triggers sections, an active Claude Code session. They test behaviour that can't be scripted: interactive prompts, Claude's response text, edge-case inputs typed at the keyboard.

## Setting up the test environment

**Before every test session:**

```bash
git checkout qa/testing
source qa/setup-env.sh
```

`setup-env.sh` creates a temporary directory (e.g. `/tmp/claude-vault-qa-XXXXXX`) and sets `$HOME` to it. This means `install.sh` writes to that temp directory, never to your real `~/.claude`. The variable `$VAULT_REPO` points to the repo root.

**Resetting between tests:**

Any test marked "Reset env" in its Preconditions means you need a clean slate. Run:

```bash
bash qa/teardown.sh && source qa/setup-env.sh
```

**After your whole test session:**

```bash
bash qa/teardown.sh
```

This removes the temp home directory. Your real `~/.claude` is never touched.

---

## Installation Tests

---

### TC-INST-001: Fresh global install — happy path

**Category:** Install
**Preconditions:** Reset env. No `~/.claude` directory in `$QA_HOME`.
**Estimated time:** 5 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. At "Your name": type `Test User` and press Enter
3. At "What are you working on?": type `Test Project` and press Enter
4. At "Where should the vault live?": type `1` (Global) and press Enter
5. At "What's your role?": type `2` (Developer) and press Enter
6. At "How much do you want Claude to explain?": type `1` (Concise) and press Enter
7. At "How should Claude handle decisions?": type `1` (Confirm first) and press Enter
8. At "Add optional starter files?": press Enter (skip)
9. At "Would you like to give your AI assistant a name?": type `skip` and press Enter
10. Wait for "Done. Your vault is ready." to appear

**Expected result:**
- Install completes without any error output
- `$QA_HOME/.claude/skills/load-memory/SKILL.md` exists
- `$QA_HOME/.claude/skills/save-memory/SKILL.md` exists
- `$QA_HOME/.claude/skills/note/SKILL.md` exists
- `$QA_HOME/.claude/skills/vault-edit/SKILL.md` exists
- `$QA_HOME/.claude/skills/setup/SKILL.md` exists
- `$QA_HOME/.claude/vault/memory.md` contains "Test User" and "Test Project"
- `$QA_HOME/.claude/CLAUDE.md` contains the text `<!-- claude-vault-start -->`
- `$QA_HOME/.claude/.vault-install` exists and contains `SCOPE=global`
- `$QA_HOME/.claude/.vault-persona` contains `PERSONA_SETUP=skip`

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-INST-002: Fresh project-scoped install

**Category:** Install
**Preconditions:** Reset env. Know the path `$VAULT_REPO` (printed by setup-env.sh).
**Estimated time:** 5 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. At "Your name": type `Test User` and press Enter
3. At "What are you working on?": type `Test Project` and press Enter
4. At "Where should the vault live?": type `2` (Project only) and press Enter
5. At "Full path to your project folder": type the value of `$VAULT_REPO` and press Enter
6. At "What's your role?": type `2` and press Enter
7. At "How much do you want Claude to explain?": type `1` and press Enter
8. At "How should Claude handle decisions?": type `1` and press Enter
9. At "Add optional starter files?": press Enter (skip)
10. At "Add vault/ to .gitignore?": type `Y` and press Enter
11. At the persona prompt: type `skip` and press Enter
12. Wait for "Done. Your vault is ready."

**Expected result:**
- `$VAULT_REPO/vault/memory.md` exists (vault is inside the project, not in `~/.claude`)
- `$VAULT_REPO/vault/directives.md` exists
- `$VAULT_REPO/CLAUDE.md` contains `<!-- claude-vault-start -->`
- `$VAULT_REPO/.gitignore` contains the line `vault/`
- `$QA_HOME/.claude/vault/` does NOT exist (nothing written to fake home vault)

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-INST-003: Reinstall — update settings only (option 1)

**Category:** Install
**Preconditions:** TC-INST-001 completed (an install exists in `$QA_HOME`). Do NOT reset env.
**Estimated time:** 4 minutes

**Steps:**
1. Note the current content of `$QA_HOME/.claude/vault/memory.md` (run: `cat $QA_HOME/.claude/vault/memory.md`)
2. Run: `bash $VAULT_REPO/install.sh`
3. The installer should detect an existing install and show: "An existing install was found."
4. At "Enter 1 or 2": type `1` (Update settings only) and press Enter
5. At "What's your role?": type `3` (Product manager) and press Enter
6. At "How much do you want Claude to explain?": press Enter (keep current)
7. At "How should Claude handle decisions?": press Enter (keep current)

**Expected result:**
- configure.sh runs (you see role/length/confirm prompts again)
- `$QA_HOME/.claude/vault/memory.md` is unchanged from step 1 (same content, same Last updated date)
- `$QA_HOME/.claude/vault/directives.md` vault-settings block now contains the product manager role line: "I am a product manager."

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-INST-004: Reinstall — full reinstall, vault content preserved

**Category:** Install
**Preconditions:** TC-INST-001 completed. Do NOT reset env.
**Estimated time:** 4 minutes

**Steps:**
1. Write sentinel text into memory.md: `echo "SENTINEL_DO_NOT_REMOVE" >> $QA_HOME/.claude/vault/memory.md`
2. Verify it's there: `grep SENTINEL $QA_HOME/.claude/vault/memory.md`
3. Run: `bash $VAULT_REPO/install.sh`
4. At "Enter 1 or 2": type `2` (Full reinstall) and press Enter
5. At "Your name": type `Test User` and press Enter
6. At "What are you working on?": type `Test Project` and press Enter
7. At scope: type `1` and press Enter
8. Complete remaining prompts with any valid choices
9. At persona prompt: type `skip` (persona file exists so this prompt may not appear — that's fine)

**Expected result:**
- Install completes successfully ("Done. Your vault is ready.")
- `grep SENTINEL $QA_HOME/.claude/vault/memory.md` still prints "SENTINEL_DO_NOT_REMOVE" (memory.md was NOT overwritten)
- All five skills are reinstalled (SKILL.md files exist under `$QA_HOME/.claude/skills/`)
- `$QA_HOME/.claude/CLAUDE.md` still contains `<!-- claude-vault-start -->`

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-INST-005: All optional files selected

**Category:** Install
**Preconditions:** Reset env.
**Estimated time:** 5 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. Complete name, project, scope (global), role, length, confirm prompts with any valid values
3. At "Add optional starter files?": type `1 2 3` and press Enter
4. At persona prompt: type `skip` and press Enter
5. Wait for install to complete

**Expected result:**
- `$QA_HOME/.claude/vault/team.md` exists
- `$QA_HOME/.claude/vault/goals.md` exists
- `$QA_HOME/.claude/vault/stack.md` exists
- All three files have non-empty content (they're not zero-byte files)

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-INST-006: Install with name containing apostrophe

**Category:** Install
**Preconditions:** Reset env.
**Estimated time:** 4 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. At "Your name": type `O'Brien` and press Enter
3. At "What are you working on?": type `Test Project` and press Enter
4. Complete remaining prompts with any valid choices (scope global, role 2, length 1, confirm 1, no extra files, persona skip)
5. Run: `cat $QA_HOME/.claude/vault/memory.md`

**Expected result:**
- Install completes without any error
- The output of `cat memory.md` shows `O'Brien` in the Owner field — character is intact, not truncated or corrupted
- No shell error output during install (specifically no "unexpected end of file" or "syntax error")

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-INST-007: Install with name containing ampersand (security test — known bug SEC-001)

**Category:** Install
**Preconditions:** Reset env.
**Estimated time:** 4 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. At "Your name": type `R&D Team` and press Enter
3. At "What are you working on?": type `Test Project` and press Enter
4. Complete remaining prompts (scope global, role 2, length 1, confirm 1, no extra files, persona skip)
5. Run: `cat $QA_HOME/.claude/vault/memory.md | head -5`

**Expected result (ideal — may currently fail due to SEC-001):**
- `memory.md` Owner field shows exactly `R&D Team`

**Known failing result (SEC-001 bug):**
- `memory.md` shows something like `RTest ProjectD Team` because `&` in sed replacement inserts the matched text (`{{NAME}}`)

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** This is a known bug tracked as SEC-001. Mark Fail if the name is corrupted. The fix requires escaping `&` in user input before passing it to `sed`.

---

### TC-INST-008: Persona — give AI a specific name

**Category:** Persona
**Preconditions:** Reset env (critical — .vault-persona must not exist).
**Estimated time:** 4 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. At "Your name": type `Alex` and press Enter
3. At "What are you working on?": type `Test Project` and press Enter
4. Complete scope, role, length, confirm prompts (type `1` or `2` for each)
5. At "Add optional starter files?": press Enter
6. At "Would you like to give your AI assistant a name?": type `Aria` and press Enter
7. At "Should the AI address you as 'Alex'?": press Enter (confirm the default)
8. Run: `cat $QA_HOME/.claude/vault/directives.md | grep -A5 'vault-persona-start'`
9. Run: `cat $QA_HOME/.claude/.vault-persona`

**Expected result:**
- `directives.md` contains `Your name is Aria. Address the user as Alex.` between the vault-persona markers
- `.vault-persona` contains `AI_NAME=Aria`
- `.vault-persona` contains `PERSONA_SETUP=named`
- `.vault-persona` contains `USER_PERSONA_NAME=Alex`

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-INST-009: Persona — let AI choose its own name

**Category:** Persona
**Preconditions:** Reset env.
**Estimated time:** 4 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. Complete name, project, scope, role, length, confirm with any valid values
3. At "Add optional starter files?": press Enter
4. At "Would you like to give your AI assistant a name?": press Enter without typing anything (blank input)
5. Run: `cat $QA_HOME/.claude/vault/directives.md | grep -A10 'vault-persona-start'`
6. Run: `cat $QA_HOME/.claude/.vault-persona`

**Expected result:**
- `directives.md` contains the ai-choose identity block: text includes "You have not been given a name yet" between the vault-persona markers
- `.vault-persona` contains `PERSONA_SETUP=ai-choose`
- `.vault-persona` contains `AI_NAME=choose`

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-INST-010: Persona — skip forever

**Category:** Persona
**Preconditions:** Reset env.
**Estimated time:** 5 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. Complete name, project, scope, role, length, confirm with any valid values
3. At "Add optional starter files?": press Enter
4. At "Would you like to give your AI assistant a name?": type `skip` and press Enter
5. Run: `cat $QA_HOME/.claude/.vault-persona`
6. Run: `grep 'vault-persona-start' $QA_HOME/.claude/vault/directives.md; echo "exit: $?"`
7. Now run install.sh again (it will detect the existing install): `bash $VAULT_REPO/install.sh`
8. Choose option `2` (Full reinstall), complete all prompts
9. Observe whether the persona prompt appears

**Expected result:**
- `.vault-persona` contains `PERSONA_SETUP=skip`
- Step 6 shows no output and "exit: 1" (the vault-persona-start marker does NOT appear in directives.md)
- On the second install (step 7–9), the "Would you like to give your AI assistant a name?" prompt does NOT appear at all

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** The skip-forever behaviour is controlled by the presence of `.vault-persona`. If that file exists, `ask_persona_setup()` returns immediately.

---

### TC-INST-011: Persona with full name and user address override

**Category:** Persona
**Preconditions:** Reset env.
**Estimated time:** 4 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. At "Your name": type `Alexandra Reyes` and press Enter
3. At "What are you working on?": type `Mobile App` and press Enter
4. Complete scope, role, length, confirm prompts
5. At "Add optional starter files?": press Enter
6. At "Would you like to give your AI assistant a name?": type `Max` and press Enter
7. At "Should the AI address you as 'Alexandra Reyes'?": type `Alex` and press Enter (nickname override)
8. Run: `grep -A3 'vault-persona-start' $QA_HOME/.claude/vault/directives.md`

**Expected result:**
- The identity line in directives.md reads exactly: `Your name is Max. Address the user as Alex.`
- The original full name "Alexandra Reyes" does NOT appear in the identity line (it was overridden by "Alex")

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

## Skills Tests

> These tests require Claude Code to be running with the vault installed. Open Claude Code after completing a fresh install (TC-INST-001). The test assumes Claude Code picks up skills from `~/.claude/skills/`.

---

### TC-SKILL-001: /load-memory — fresh vault

**Category:** Skills
**Preconditions:** TC-INST-001 completed. Open a new Claude Code session (in any directory).
**Estimated time:** 3 minutes

**Steps:**
1. Open Claude Code: `claude` (in any terminal)
2. In the Claude Code prompt, type: `/load-memory`
3. Read Claude's response

**Expected result:**
- Claude responds with the exact phrase "🧠 I know kung fu." as the first line
- Following that, Claude writes a short paragraph (not a bullet list) covering: the project name (from memory.md), the current focus, and one or two active constraints
- Claude does NOT ask any questions or prompt for clarification
- No error about vault not found

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-SKILL-002: /load-memory — mid-session refresh

**Category:** Skills
**Preconditions:** TC-INST-001 completed. Have an active Claude Code session.
**Estimated time:** 5 minutes

**Steps:**
1. In Claude Code, have a multi-turn conversation about something unrelated to your project — for example, ask Claude to explain how HTTP caching works
2. Continue for at least 3 exchanges so the conversation has real context
3. Now type: `/load-memory`
4. Check Claude's response

**Expected result:**
- Claude responds with "🧠 I know kung fu." regardless of the previous conversation
- Claude re-anchors to the vault (mentions the project name and current focus from memory.md), not the HTTP caching discussion
- The context switch is clean — Claude doesn't mix vault content with the previous conversation topic

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-SKILL-003: /save-memory — basic checkpoint

**Category:** Skills
**Preconditions:** TC-INST-001 completed. Active Claude Code session.
**Estimated time:** 6 minutes

**Steps:**
1. In Claude Code, have a short conversation with a concrete decision. For example:
   - You: "I'm thinking about whether to use SQLite or Postgres for this project"
   - Claude: (responds with tradeoffs)
   - You: "Let's go with Postgres — we'll need multi-user concurrency later"
2. Type: `/save-memory`
3. Read Claude's response
4. In a separate terminal, run: `cat $QA_HOME/.claude/vault/memory.md`

**Expected result:**
- Claude responds with "🔥 Bonfire lit, memory preserved." as the first line
- Claude follows with a brief bullet list of what changed (should include the Postgres decision)
- `memory.md` "Last updated" date is today's date
- `memory.md` "Recent decisions" section contains a line about choosing Postgres

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-SKILL-004: /note with inline text

**Category:** Skills
**Preconditions:** TC-INST-001 completed. Active Claude Code session.
**Estimated time:** 3 minutes

**Steps:**
1. In Claude Code, type exactly: `/note using Tailwind for all styling — no CSS modules`
2. Read Claude's response
3. In a separate terminal, run: `cat $QA_HOME/.claude/vault/memory.md`

**Expected result:**
- Claude responds with "📌 Noted." as the first line
- Claude shows exactly what was added and which section it was placed under
- `memory.md` "Recent decisions" section contains the new line about Tailwind (verbatim or near-verbatim)
- No other existing lines in memory.md were modified or removed

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-SKILL-005: /note without text — AI infers from conversation

**Category:** Skills
**Preconditions:** TC-INST-001 completed. Active Claude Code session.
**Estimated time:** 5 minutes

**Steps:**
1. In Claude Code, have a short conversation that includes a clear decision:
   - You: "Should we use a monorepo or separate repos for this?"
   - Claude: (responds)
   - You: "Let's go monorepo — easier to keep packages in sync"
2. Now type just: `/note` (no additional text)
3. Read Claude's proposed capture
4. Type: `yes` (or press Enter if Claude offers a confirm shortcut) to confirm

**Expected result:**
- Claude surfaces a confirmation prompt like: "Should I note: [one-line summary of the monorepo decision]?" — it does NOT just silently write
- After confirmation, Claude responds with "📌 Noted."
- `memory.md` contains a new line about the monorepo decision

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-SKILL-006: /vault-edit — update memory

**Category:** Skills
**Preconditions:** TC-INST-001 completed. Active Claude Code session.
**Estimated time:** 5 minutes

**Steps:**
1. In Claude Code, type: `/vault-edit`
2. When Claude acknowledges the skill, say: "Update the 'Current focus' section in memory.md — I'm now working on the authentication flow"
3. Read Claude's response
4. If Claude shows a before/after diff, type `yes` to confirm
5. In a separate terminal, run: `cat $QA_HOME/.claude/vault/memory.md`

**Expected result:**
- Claude shows the current value of "Current focus" before proposing any change
- Claude proposes an update and shows a clear before/after diff
- Claude waits for confirmation before writing
- After confirmation, `memory.md` "Current focus" section reflects the authentication flow update
- No other sections of memory.md were silently changed

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-SKILL-007: /setup — change a setting in-session

**Category:** Skills
**Preconditions:** TC-INST-001 completed (developer role, concise, confirm-first). Active Claude Code session.
**Estimated time:** 5 minutes

**Steps:**
1. In Claude Code, type: `/setup`
2. Say: "Change my response style to detailed"
3. Read Claude's proposal
4. Type `yes` to confirm the change
5. In a separate terminal, run: `grep -A10 'vault-settings-start' $QA_HOME/.claude/vault/directives.md`

**Expected result:**
- Claude shows the current setting ("Be concise. Short answers...") before proposing the change
- Claude proposes replacing it with the detailed variant ("Explain your reasoning...")
- Claude shows a diff (before/after)
- After confirmation, the vault-settings block in directives.md now shows the detailed length directive
- The rest of directives.md (user-written sections like "How I like to work", "Quality rules") is unchanged

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

## Decision Trigger Tests

> These tests require an active Claude Code session with the vault loaded. The triggers come from the directives.md "Memory stewardship" section, which Claude reads each session.

---

### TC-TRIG-001: "let's go with" trigger

**Category:** Triggers
**Preconditions:** TC-INST-001 completed. Active Claude Code session, vault loaded.
**Estimated time:** 3 minutes

**Steps:**
1. In Claude Code, type: `I've been evaluating React vs Vue for this project. Let's go with React — it has better ecosystem support for what we need.`
2. Read Claude's complete response

**Expected result:**
- Claude's response ends with a line like: `📌 /note using React — better ecosystem support`
- The 📌 line is the last thing in Claude's response (or very near the end)
- The suggestion is a ready-to-run command, not just a description

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-TRIG-002: "we decided" trigger

**Category:** Triggers
**Preconditions:** Active Claude Code session with vault loaded.
**Estimated time:** 3 minutes

**Steps:**
1. In Claude Code, type: `We decided to use a monorepo structure — it keeps shared types in one place and avoids versioning headaches.`
2. Read Claude's complete response

**Expected result:**
- Claude's response includes a `📌 /note ...` suggestion at the end
- The suggested note captures the monorepo decision in one line

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-TRIG-003: "from now on" trigger — may suggest directives.md

**Category:** Triggers
**Preconditions:** Active Claude Code session with vault loaded.
**Estimated time:** 4 minutes

**Steps:**
1. In Claude Code, type: `From now on always use async/await, never .then() chains. It's a hard rule for this codebase.`
2. Read Claude's complete response

**Expected result:**
- Claude's response includes a `📌 /note ...` suggestion at the end
- Because this is a standing rule ("from now on"), Claude may additionally suggest adding it to `directives.md` instead of `memory.md` — both outcomes are acceptable, but the suggestion to use directives.md is the higher-quality behaviour

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** If Claude only suggests /note to memory.md without mentioning directives.md, that's a Partial Pass — record what actually happened.

---

### TC-TRIG-004: Natural stopping point trigger

**Category:** Triggers
**Preconditions:** Active Claude Code session with vault loaded.
**Estimated time:** 4 minutes

**Steps:**
1. In Claude Code, simulate completing a meaningful task. Type: `The authentication flow is done. Login, logout, JWT refresh, and the protected routes are all working and tested.`
2. Read Claude's complete response

**Expected result:**
- Claude's response includes a `🔥 /save-memory to lock this in.` suggestion at the end
- The suggestion is a ready-to-run command (not just a description of what to do)

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-TRIG-005: Stale data flag

**Category:** Triggers
**Preconditions:** Reset env, fresh install. Do NOT use the Claude Code session from the previous tests — start a new one.
**Estimated time:** 6 minutes

**Steps:**
1. Manually edit memory.md to add an obviously outdated entry:
   ```
   echo "- Using React 17 (legacy class components)" >> $QA_HOME/.claude/vault/memory.md
   ```
2. Open a new Claude Code session: `claude`
3. Type: `/load-memory`
4. After Claude loads the vault, type: `What version of React are we using?`
5. Read Claude's response

**Expected result:**
- Claude loads the vault including the React 17 line
- When asked about the React version, Claude flags the potentially stale entry: something like "[React 17] in memory.md looks stale — still accurate?" or asks you to confirm before treating it as current
- Claude does NOT just confidently assert "You're using React 17" without flagging the stale concern

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** This trigger depends on Claude noticing that "React 17" is a specific old version number. If Claude flags it, that's a Pass. If Claude accepts it without comment, that's a Fail.

---

## Uninstall Tests

---

### TC-UINS-001: Clean uninstall

**Category:** Uninstall
**Preconditions:** TC-INST-001 completed (fresh global install). Do NOT reset env.
**Estimated time:** 4 minutes

**Steps:**
1. Confirm vault is installed: `ls $QA_HOME/.claude/skills/`
2. Run: `bash $VAULT_REPO/uninstall.sh`
3. When prompted "Are you sure?": type `y` and press Enter
4. Run the following checks:
   - `grep 'claude-vault-start' $QA_HOME/.claude/CLAUDE.md; echo "exit: $?"`
   - `ls $QA_HOME/.claude/skills/`
   - `ls $QA_HOME/.claude/vault/`
   - `ls $QA_HOME/.claude/.vault-install 2>&1`

**Expected result:**
- `grep` for `claude-vault-start` finds nothing ("exit: 1")
- `ls skills/` shows no load-memory, save-memory, note, vault-edit, or setup directories
- `ls vault/` still shows `memory.md` and `directives.md` (vault is preserved, not deleted)
- `ls .vault-install` shows "No such file or directory" (.vault-install is removed)

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-UINS-002: Uninstall with existing CLAUDE.md content preserved

**Category:** Uninstall
**Preconditions:** Reset env.
**Estimated time:** 6 minutes

**Steps:**
1. Create a CLAUDE.md with pre-existing content before installing:
   ```bash
   mkdir -p $QA_HOME/.claude
   cp $VAULT_REPO/qa/fixtures/dirty-claude.md $QA_HOME/.claude/CLAUDE.md
   ```
2. Run: `bash $VAULT_REPO/install.sh` and complete a standard global install
3. Verify the vault section was appended: `grep 'claude-vault-start' $QA_HOME/.claude/CLAUDE.md`
4. Verify the original content is still there: `grep 'Always respond in the language' $QA_HOME/.claude/CLAUDE.md`
5. Run: `bash $VAULT_REPO/uninstall.sh` and confirm with `y`
6. Run:
   - `grep 'claude-vault-start' $QA_HOME/.claude/CLAUDE.md; echo "vault block: $?"`
   - `grep 'Always respond in the language' $QA_HOME/.claude/CLAUDE.md; echo "original: $?"`

**Expected result:**
- After uninstall: `grep 'claude-vault-start'` returns nothing ("vault block: 1")
- After uninstall: `grep 'Always respond in the language'` still finds the line ("original: 0") — original content was preserved

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-UINS-003: Uninstall is cancellable

**Category:** Uninstall
**Preconditions:** TC-INST-001 completed. Do NOT reset env.
**Estimated time:** 2 minutes

**Steps:**
1. Note that the install exists: `ls $QA_HOME/.claude/.vault-install`
2. Run: `bash $VAULT_REPO/uninstall.sh`
3. When prompted "Are you sure?": type `n` and press Enter
4. Check: `ls $QA_HOME/.claude/.vault-install`
5. Check: `ls $QA_HOME/.claude/skills/`

**Expected result:**
- Uninstall prints a cancellation message and exits cleanly (exit 0)
- `.vault-install` still exists
- All five skill directories still exist under `skills/`
- CLAUDE.md still contains the `<!-- claude-vault-start -->` block

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-UINS-004: Uninstall when not installed

**Category:** Uninstall
**Preconditions:** Reset env (no vault installed in `$QA_HOME`).
**Estimated time:** 2 minutes

**Steps:**
1. Confirm vault is NOT installed: `ls $QA_HOME/.claude/ 2>&1` (should show nothing or "No such file or directory")
2. Run: `bash $VAULT_REPO/uninstall.sh`
3. Note the exit code: `echo "exit: $?"`

**Expected result:**
- Uninstall prints a message like "nothing to uninstall" or "no vault detected" (graceful, not a bash error)
- Exit code is 0 (not a crash)
- No files were created or deleted

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

## Edge Case Tests

---

### TC-EDGE-001: Empty name input

**Category:** Edge Cases
**Preconditions:** Reset env.
**Estimated time:** 3 minutes

**Steps:**
1. Run: `bash $VAULT_REPO/install.sh`
2. At "Your name": press Enter immediately (empty input)
3. At "What are you working on?": type `Test Project` and press Enter
4. Complete remaining prompts with any valid choices
5. Run: `cat $QA_HOME/.claude/vault/memory.md | head -5`

**Expected result:**
- Install completes without crashing or printing a bash error
- `memory.md` Owner field is blank (just `**Owner:** `) or shows a placeholder — it is NOT corrupted or missing

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-EDGE-002: Very long project name

**Category:** Edge Cases
**Preconditions:** Reset env.
**Estimated time:** 3 minutes

**Steps:**
1. Generate a 200-character string: `LONG_NAME=$(python3 -c "print('A' * 200)")`
2. Run: `bash $VAULT_REPO/install.sh`
3. At "Your name": type `Test User` and press Enter
4. At "What are you working on?": paste the 200-character string (copy from: `echo $LONG_NAME`) and press Enter
5. Complete remaining prompts with any valid choices
6. Run: `cat $QA_HOME/.claude/vault/memory.md | head -5`

**Expected result:**
- Install completes without crashing
- `memory.md` Project field contains the 200-character string without truncation or corruption
- No "argument list too long" or similar OS error

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-EDGE-003: /note when vault directory is missing

**Category:** Edge Cases
**Preconditions:** TC-INST-001 completed. Active Claude Code session.
**Estimated time:** 4 minutes

**Steps:**
1. In a separate terminal, move the vault directory: `mv $QA_HOME/.claude/vault $QA_HOME/.claude/vault-hidden`
2. In Claude Code, type: `/note API base URL is https://api.example.com`
3. Read Claude's response
4. Restore the vault: `mv $QA_HOME/.claude/vault-hidden $QA_HOME/.claude/vault`

**Expected result:**
- Claude does NOT crash or throw an unhandled error
- Claude says something like "I can't find the vault directory" and suggests running `./install.sh` or `/setup` to fix it
- Claude does NOT silently write to a wrong location

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-EDGE-004: memory.md over 80 lines triggers distillation warning

**Category:** Edge Cases
**Preconditions:** TC-INST-001 completed. Active Claude Code session.
**Estimated time:** 5 minutes

**Steps:**
1. In a separate terminal, pad memory.md to over 80 lines:
   ```bash
   for i in $(seq 1 20); do echo "- Filler decision number $i" >> $QA_HOME/.claude/vault/memory.md; done
   ```
2. Verify line count: `wc -l $QA_HOME/.claude/vault/memory.md` (should be over 80)
3. In Claude Code, type: `/save-memory`
4. Read Claude's response

**Expected result:**
- Claude acknowledges that memory.md exceeds the 80-line limit
- Claude distills the content aggressively, removing redundant or stale filler lines
- Claude proposes the distilled version and waits for confirmation before writing
- After confirming, `wc -l $QA_HOME/.claude/vault/memory.md` shows under 80 lines

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

### TC-EDGE-005: Install when ~/.claude does not exist

**Category:** Edge Cases
**Preconditions:** Reset env. Verify `$QA_HOME/.claude` does not exist: `ls $QA_HOME/.claude 2>&1`
**Estimated time:** 4 minutes

**Steps:**
1. Confirm `$QA_HOME/.claude` does not exist yet
2. Run: `bash $VAULT_REPO/install.sh`
3. Complete all prompts with any valid values (scope: global)
4. Run: `ls $QA_HOME/.claude/`

**Expected result:**
- Install completes without any "No such file or directory" errors
- `$QA_HOME/.claude/` was created by the installer
- All expected files are present: `vault/memory.md`, `vault/directives.md`, `CLAUDE.md`, `.vault-install`, `.vault-persona`, `skills/` with five subdirectories

**Actual result:** ________________________________

**Pass / Fail:** [ ] Pass  [ ] Fail

**Notes:** ________________________________

---

*End of manual test cases. For automated checks, run `bash qa/run-senior.sh` from the repo root.*
