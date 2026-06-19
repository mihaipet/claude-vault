# Claude Vault

[![tests](https://github.com/mihaipet/claude-vault/actions/workflows/test.yml/badge.svg)](https://github.com/mihaipet/claude-vault/actions/workflows/test.yml)

A lightweight second brain for Claude Code. Two files, six skills, ten minutes to set up.

Claude forgets everything when a session ends. This gives it a place to remember — and a way to grow that memory over time.

---

## What's inside

**Two files hold your memory:**

| File | What it does |
|---|---|
| `memory.md` | Your current project state. What you're focused on, next tasks, recent decisions, open questions. Claude reads this every session. |
| `directives.md` | Standing rules. How you like to work, quality standards, project conventions. Claude follows these without being told. |

**Six skills work the memory:**

| Skill | What it does |
|---|---|
| `/load-memory` | Reload every vault file mid-session to refresh Claude's context. |
| `/save-memory` | Checkpoint the session into `memory.md` — extracts state, decisions, and next steps. |
| `/note` | Quick-capture a single decision or rule without a full checkpoint. |
| `/vault-edit` | Manually update and grow your vault files over time. |
| `/setup` | Review and change your settings from inside Claude Code. |
| `/update` | Check your installed version and get the command to update. |

---

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated — run `claude --version` to check
- VS Code with the Claude Code extension

---

## Install

```bash
git clone https://github.com/mihaipet/claude-vault.git
cd claude-vault
./install.sh
```

---

## What the installer asks

**1. Your name and project**
Used to personalise `memory.md`.

**2. Where to install**
- *Global* (`~/.claude/`) — vault works across all your projects. Recommended for first setup.
- *Project only* — vault lives inside a specific project folder. Useful if you want separate vaults per project. You'll also be asked if you want to add vault files to `.gitignore`.

**3. Your role**
Tells Claude how to calibrate responses. Designer, developer, PM, researcher, or skip.

**4. Response length**
Concise (short answers, no padding) or detailed (explain reasoning, show the why).

**5. Confirmation style**
Confirm before every action, or proceed and flag uncertainty.

**6. Optional starter files**
Add any combination of:
- `team.md` — who's on the team, who decides what
- `goals.md` — what you're trying to achieve this period
- `stack.md` — tools, tech, project conventions

**7. One-time persona setup**
Optionally give your AI assistant a name — type one, let it pick its own, or skip. You can also choose how it addresses you. Asked once, then never again (stored in `~/.claude/.vault-persona`).

---

## Changing your settings

**From the terminal:**
```bash
./configure.sh
```
Re-runs the settings questions and updates `directives.md`. Never touches your vault content.

**From inside Claude Code:**
```
/setup
```
Shows your current settings and lets you change specific items without leaving your session.

**Re-running the full installer:**
If an existing install is detected, `install.sh` offers a menu — *use existing setup* (refreshes skills, no questions) or *change setup* (answer the questions again). Vault files are never overwritten on reinstall.

---

## Using the vault day to day

**Pull context in — `/load-memory`**

Type `/load-memory` to reload every vault file mid-session. Use it when starting a new task, returning after a break, or when the conversation has drifted and you want Claude back on track.

**Capture as you go — `/note`**

Type `/note using Postgres for the database` to append a single decision to `memory.md` on the spot — no full checkpoint needed. Run `/note` alone and Claude proposes the most recent decision from the conversation for you to confirm.

**Checkpoint a session — `/save-memory`**

Type `/save-memory` at the end of a session or after a major decision. Claude reviews the conversation, extracts current state, decisions, lessons, and next steps, and merges them into `memory.md`. It proposes any new standing rules for `directives.md` before writing.

**Grow the files by hand — `/vault-edit`**

Type `/vault-edit` to update files manually, add a directive when you've corrected Claude for the same thing twice, or create a new vault file when a topic outgrows `memory.md` and `directives.md`.

**Reviewing your settings — `/setup`**

Type `/setup` to see your current role, response length, and confirmation style, change any setting in plain language, or add entries to `directives.md`.

---

## Plugins

Plugins extend your vault with domain-specific templates and skills.
The plugin architecture is in place — first plugins are coming soon.

**Planned:**
- `design-system` — import and maintain design system context (tokens, components, conventions)

Plugins are offered during install. To install a plugin after the initial setup, re-run `install.sh` and choose option 2 — your vault files are preserved.

---

## Updating

```bash
./update.sh
```

Checks your installed version against the latest on GitHub, shows what's new, and — if you confirm — pulls the changes and reapplies them using your existing settings (no questions). Requires that you installed from a git clone. From inside Claude Code, `/update` reports your current version and the exact command to run.

---

## Uninstall

```bash
./uninstall.sh
```

Removes the vault block from CLAUDE.md, uninstalls all skills (`/load-memory`, `/save-memory`, `/note`, `/vault-edit`, `/setup`, `/update`), and deletes the install and persona configs. Your vault files (`memory.md`, `directives.md`, etc.) are never deleted — they stay at their install location. Delete them manually if you no longer need them.

---

## File structure after install

**Global install:**
```
~/.claude/
  CLAUDE.md                 ← vault reference, read by Claude in every project
  .vault-install            ← install config, enables auto-detection across sessions
  .vault-persona            ← persona config, set once during setup
  skills/
    load-memory/SKILL.md    ← /load-memory skill
    save-memory/SKILL.md    ← /save-memory skill
    note/SKILL.md           ← /note skill
    vault-edit/SKILL.md     ← /vault-edit skill
    setup/SKILL.md          ← /setup skill
    update/SKILL.md         ← /update skill
  vault/
    memory.md
    directives.md
    team.md                 ← if selected
    goals.md                ← if selected
    stack.md                ← if selected
```

**Project install:**
```
your-project/
  .gitignore                ← vault/ added if requested
  CLAUDE.md                 ← vault reference
  vault/
    memory.md
    directives.md
    ...
~/.claude/skills/           ← skills always install globally
  load-memory/SKILL.md
  save-memory/SKILL.md
  note/SKILL.md
  vault-edit/SKILL.md
  setup/SKILL.md
  update/SKILL.md
```

---

## Safe to re-run

`install.sh` and `configure.sh` never overwrite existing vault content. Memory and directives are yours — only the auto-generated settings block in `directives.md` is updated on reconfigure.
