# Claude Vault

A lightweight second brain for Claude Code. Two files, two skills, ten minutes to set up.

Claude forgets everything when a session ends. This gives it a place to remember — and a way to grow that memory over time.

---

## What's inside

| File | What it does |
|---|---|
| `memory.md` | Your current project state. What you're focused on, recent decisions, open questions. Claude reads this every session. |
| `directives.md` | Standing rules. How you like to work, quality standards, project conventions. Claude follows these without being told. |
| `/vault-edit` skill | Tells Claude how to update and grow your vault files over time. |
| `/setup` skill | Lets you review and change your settings from inside Claude Code. |

---

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated — run `claude --version` to check
- VS Code with the Claude Code extension

---

## Install

```bash
git clone https://github.com/mihaipet/claude-vault.git
cd claude-vault
chmod +x install.sh configure.sh uninstall.sh
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
If an existing install is detected, `install.sh` offers a menu — update settings only, or full reinstall. Vault files are never overwritten on reinstall.

---

## Using the vault day to day

**Growing your second brain — `/vault-edit`**

Type `/vault-edit` in Claude Code to:
- Update `memory.md` after a session — what happened, what was decided, what to pick up next
- Add a new directive when you find yourself correcting Claude for the same thing twice
- Create a new vault file when a topic outgrows `memory.md` and `directives.md`

**Reviewing your settings — `/setup`**

Type `/setup` to:
- See your current role, response length, and confirmation style
- Change any setting in plain language
- Add or update entries in `directives.md`

---

## Plugins

Plugins extend your vault with domain-specific templates and skills.
The plugin architecture is in place — first plugins are coming soon.

**Planned:**
- `design-system` — import and maintain design system context (tokens, components, conventions)

Plugins are offered during install. To install a plugin after the initial setup, re-run `install.sh` and choose option 2 — your vault files are preserved.

---

## Uninstall

```bash
./uninstall.sh
```

Removes the vault block from CLAUDE.md, uninstalls skills (`/vault-edit`, `/setup`), and deletes the install config. Your vault files (`memory.md`, `directives.md`, etc.) are never deleted — they stay at their install location. Delete them manually if you no longer need them.

---

## File structure after install

**Global install:**
```
~/.claude/
  CLAUDE.md               ← vault reference, read by Claude in every project
  .vault-install          ← install config, enables auto-detection across sessions
  skills/
    vault-edit/SKILL.md   ← /vault-edit skill
    setup/SKILL.md        ← /setup skill
  vault/
    memory.md
    directives.md
    team.md               ← if selected
    goals.md              ← if selected
    stack.md              ← if selected
```

**Project install:**
```
your-project/
  .gitignore              ← vault/ added if requested
  CLAUDE.md               ← vault reference
  vault/
    memory.md
    directives.md
    ...
~/.claude/skills/         ← skills always install globally
  vault-edit/SKILL.md
  setup/SKILL.md
```

---

## Safe to re-run

`install.sh` and `configure.sh` never overwrite existing vault content. Memory and directives are yours — only the auto-generated settings block in `directives.md` is updated on reconfigure.
