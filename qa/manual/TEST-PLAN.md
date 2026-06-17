# claude-vault QA Test Plan

**Version:** 1.0.0  
**Document status:** Living document — update when new findings are filed or tests are added.  
**Scope:** Release QA for claude-vault v1.0.0 and all subsequent patch releases.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Test Environment Requirements](#2-test-environment-requirements)
3. [Test Categories](#3-test-categories)
   - 3.1 [Security](#31-security)
   - 3.2 [Architecture & Design](#32-architecture--design)
   - 3.3 [Integration](#33-integration)
   - 3.4 [Regression](#34-regression)
   - 3.5 [Performance](#35-performance)
   - 3.6 [User Experience — Skill Functionality](#36-user-experience--skill-functionality)
   - 3.7 [Edge Cases & Error Handling](#37-edge-cases--error-handling)
4. [Known Issues](#4-known-issues)
5. [Test Execution Checklist](#5-test-execution-checklist)
6. [Pass / Fail Criteria](#6-pass--fail-criteria)
7. [Reporting](#7-reporting)

---

## 1. Executive Summary

### What this plan covers

This test plan governs manual and automated quality assurance for **claude-vault**, a bash-based second-brain system for Claude Code (Anthropic's AI coding assistant). It covers the full installation lifecycle (fresh install, reinstall, configure, uninstall), all five slash-command skills, file integrity guarantees, security properties, and observed regressions.

### In scope

- `install.sh`, `configure.sh`, `uninstall.sh`
- Library modules: `lib/version.sh`, `lib/vault.sh`, `lib/settings.sh`, `lib/plugins.sh`
- All five skills: `load-memory`, `save-memory`, `note`, `vault-edit`, `setup`
- Installed artefacts: `~/.claude/CLAUDE.md` vault block, `~/.claude/vault/`, `~/.claude/skills/`, `~/.claude/.vault-install`, `~/.claude/.vault-persona`
- Project-scoped installs (non-global `$PROJECT_PATH`)
- The existing 35-test unit suite in `test/run.sh`
- The senior automated checks in `qa/senior/`

### Out of scope

- Claude Code's own behaviour (model output quality is tested only at the smoke-test level)
- Network requests (claude-vault makes none)
- Windows / WSL environments (bash 3.2+/5+ on macOS and Linux only)
- CI/CD pipeline configuration
- Plugin ecosystem beyond the five bundled skills

---

## 2. Test Environment Requirements

### 2.1 Shell requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| bash | 3.2 (macOS default) | 5.2 (Linux) |
| awk | POSIX awk or gawk | gawk 5+ |
| sed | BSD sed (macOS) or GNU sed | either |
| realpath | coreutils (Linux) | GNU coreutils |

Verify before running any test:

```bash
bash --version | head -1
awk --version  | head -1
```

bash 3.2 is deliberately supported because macOS ships it. Tests that expose bash-4+ behaviour differences must note the minimum version.

### 2.2 Sandboxed QA environment

All tests must run against a **sandboxed** `$HOME`, never the tester's real `~/.claude`. The sandbox is provided by `qa/setup-env.sh`.

```bash
# From the repo root — source (not run) this file
source qa/setup-env.sh
```

After sourcing, the following variables are set for the current shell:

| Variable | Value | Purpose |
|---|---|---|
| `QA_HOME` | `/tmp/claude-vault-qa-XXXXXX` | Sandboxed home root |
| `HOME` | same as `QA_HOME` | Redirects all `$HOME` references |
| `VAULT_REPO` | `/home/user/claude-vault` (or wherever the repo lives) | Repo root for scripts |

To tear down:

```bash
bash qa/teardown.sh
```

**Never run install/uninstall scripts without sourcing `qa/setup-env.sh` first.** Check the guard:

```bash
echo $QA_HOME   # must not be empty
```

### 2.3 Claude Code version for skill testing

Skill functionality (section 3.6) requires a live Claude Code session. Skills are invoked as slash commands and interpreted by the model, so model behaviour can vary between versions.

- Record the Claude Code version under test: `claude --version`
- Record the model name/ID reported at session start
- Skill tests are necessarily semi-manual; document the session transcript for any failures

---

## 3. Test Categories

---

### 3.1 Security

Security findings use severity levels: **HIGH**, **MEDIUM**, **LOW**, **INFO** (see section 7).

The automated checks in `qa/senior/security.sh` cover SEC-001 through SEC-008. The checks below are the canonical definitions; the script is the execution mechanism.

#### SEC-001 — Sed injection via user input (HIGH)

**Risk:** `USER_NAME` and `PROJECT_NAME` are interpolated directly into `sed` replacement strings in `install.sh`. Characters that sed treats as delimiters or metacharacters (`&`, `/`, `\`) silently corrupt output or inject arbitrary content.

**What to check:**

```bash
grep -n 's/.*USER_NAME\|s/.*PROJECT_NAME' /home/user/claude-vault/install.sh
```

Look for any pattern of the form `sed "s/PLACEHOLDER/$USER_NAME/"` where the variable is not sanitised before use.

**Manual test:** During install, enter `O'Brien & Sons` as the project name. Inspect the written `CLAUDE.md` vault block — it must contain the literal string `O'Brien & Sons`, not a corrupted or truncated version.

**Fix requirement:** Escape `&` → `\&` and `/` → `\/` before sed substitution, or switch to `awk` for replacements.

**Current status:** OPEN (see Known Issues — SEC-001).

#### SEC-002 — Path traversal via PROJECT_PATH (HIGH)

**Risk:** When the user supplies a project path for a scoped install, the value is used directly without canonicalisation. A path like `../../etc` would write vault files outside the intended project directory.

**What to check:**

```bash
grep -n 'PROJECT_PATH' /home/user/claude-vault/install.sh | head -20
```

There should be a `realpath` or `readlink -f` call before `PROJECT_PATH` is first used as a directory.

**Manual test:**

```bash
source qa/setup-env.sh
bash /home/user/claude-vault/install.sh
# When prompted for scope, choose project-scoped
# When prompted for path, enter: /tmp/../../tmp/traversal-test
# Verify: no files written outside /tmp/traversal-test
```

**Fix requirement:** `PROJECT_PATH=$(realpath "$PROJECT_PATH")` before first use.

**Current status:** OPEN (see Known Issues — SEC-002).

#### SEC-003 — Source injection via .vault-install (HIGH)

**Risk:** `lib/vault.sh:detect_vault()` sources `~/.claude/.vault-install` to read the vault path. If a malicious or corrupted `.vault-install` contains shell commands, they execute with the user's privileges when any skill or script calls `detect_vault`.

**What to check:**

```bash
grep -n 'source\|\.' /home/user/claude-vault/lib/vault.sh
```

The `.vault-install` file must be treated as a config file (read with `grep`/`awk`), not executed via `.` or `source`.

**Manual test:**

```bash
echo 'echo INJECTED > /tmp/injection-proof' >> "$HOME/.claude/.vault-install"
# Source lib/vault.sh and call detect_vault
source /home/user/claude-vault/lib/vault.sh
detect_vault
# FAIL if /tmp/injection-proof exists
```

**Fix requirement:** Replace `source "$INSTALL_CONFIG"` with explicit key=value parsing using `grep` or `awk`.

**Current status:** OPEN — flag as HIGH until resolved.

#### SEC-004 — File permissions on sensitive config files (MEDIUM)

`.vault-install` and `.vault-persona` contain user-specific configuration. They must not be world-readable.

**What to check after install:**

```bash
stat -c '%a %n' "$HOME/.claude/.vault-install"
stat -c '%a %n' "$HOME/.claude/.vault-persona"
```

Expected: mode `600` (owner read/write only). Fail if mode is `644` or broader.

The automated check in `security.sh` (SEC-004) verifies this. The manual check confirms it on a real install, not just a fixture.

#### SEC-005 — AI_NAME sanitisation (MEDIUM)

**Risk:** The AI persona name entered by the user is written into `CLAUDE.md` and `directives.md`. If it contains YAML-significant characters or shell metacharacters, downstream processing may be affected.

**Manual test:** At the persona prompt, enter `"; rm -rf /; echo "`. Inspect the written `.vault-persona` and the CLAUDE.md vault block. The literal string must appear, escaped, with no command execution.

#### SEC-006 — Temp file handling (LOW)

**What to check:**

```bash
grep -n 'mktemp\|/tmp/' /home/user/claude-vault/install.sh \
  /home/user/claude-vault/lib/*.sh
```

Temp files created during install (e.g., for awk rewrites of CLAUDE.md) must be removed on both success and failure paths. Check for a `trap` on `EXIT` or equivalent cleanup.

#### SEC-007 — No use of eval (LOW)

```bash
grep -rn '\beval\b' /home/user/claude-vault/
```

Zero matches expected. Any `eval` use requires explicit justification.

#### SEC-008 — rm -rf path safety (LOW)

```bash
grep -n 'rm -rf' /home/user/claude-vault/uninstall.sh
```

Every `rm -rf` must operate on a fully-qualified, non-empty variable path. Pattern `rm -rf "$VAR"` where `VAR` could be empty is a HIGH severity finding if present.

---

### 3.2 Architecture & Design

Architecture findings use severity levels: **BUG**, **ARCH**, **WARN** (see section 7).

The automated checks in `qa/senior/architecture.sh` cover ARCH-001 through ARCH-011.

#### ARCH-001 — Uninstall removes all installed skills (BUG)

`install.sh` installs five skills into `~/.claude/skills/`:

1. `load-memory`
2. `save-memory`
3. `note`
4. `vault-edit`
5. `setup`

`uninstall.sh` removes only `load-memory` and `save-memory`. The other three are orphaned after uninstall.

**Verification:**

```bash
source qa/setup-env.sh
bash /home/user/claude-vault/install.sh   # non-interactive: pipe yes/defaults
ls "$HOME/.claude/skills/"                # expect 5 entries
bash /home/user/claude-vault/uninstall.sh
ls "$HOME/.claude/skills/"                # FAIL if any entry remains
```

**Current status:** OPEN (see Known Issues — BUG-001).

#### ARCH-002 — Uninstall uses hardcoded marker strings (BUG)

`uninstall.sh` must use `VAULT_CLAUDE_START` and `VAULT_CLAUDE_END` from `lib/version.sh`, not hardcoded strings. A mismatch between the constants and hardcoded strings causes uninstall to fail silently (the block remains in CLAUDE.md).

**What to check:**

```bash
grep -n 'claude-vault-start\|claude-vault-end' /home/user/claude-vault/uninstall.sh
grep -n 'VAULT_CLAUDE_START\|VAULT_CLAUDE_END'  /home/user/claude-vault/uninstall.sh
```

Expect: zero raw string matches, one or more constant references. Current state inverts this.

**Current status:** OPEN (see Known Issues — BUG-002).

#### ARCH-003 — Idempotency: N installs = same result

Running `install.sh` twice must produce the same file state as running it once. The vault block in CLAUDE.md must not be duplicated; vault files must not be overwritten.

**Verification:**

```bash
source qa/setup-env.sh
bash /home/user/claude-vault/install.sh   # first run
md5sum "$HOME/.claude/vault/memory.md" "$HOME/.claude/vault/directives.md" > /tmp/before.md5
bash /home/user/claude-vault/install.sh   # second run (reinstall)
md5sum "$HOME/.claude/vault/memory.md" "$HOME/.claude/vault/directives.md" > /tmp/after.md5
diff /tmp/before.md5 /tmp/after.md5       # PASS: no diff
grep -c 'claude-vault-start' "$HOME/.claude/CLAUDE.md"  # PASS: exactly 1
```

#### ARCH-004 — Marker boundary integrity: only managed regions are touched

Content outside the `<!-- claude-vault-start -->` / `<!-- claude-vault-end -->` and `<!-- vault-settings-start -->` / `<!-- vault-settings-end -->` markers in CLAUDE.md must survive all install/reinstall/configure cycles unchanged.

**Verification:**

```bash
echo "MY CUSTOM CONTENT" >> "$HOME/.claude/CLAUDE.md"
bash /home/user/claude-vault/install.sh   # reinstall
grep "MY CUSTOM CONTENT" "$HOME/.claude/CLAUDE.md"  # PASS: must still be present
```

#### ARCH-005 — configure.sh refreshes skills (ARCH)

`configure.sh` is the upgrade path. It must reinstall skills so that new skills added in later versions are deployed when a user runs `configure`. Currently it does not.

**What to check:**

```bash
grep -n 'install_plugin\|skills' /home/user/claude-vault/configure.sh
```

Expect: `install_plugin` called for each skill, or a loop over `skills/`. Current state: absent.

**Current status:** OPEN (see Known Issues — ARCH-001).

#### ARCH-006 — Persona marker constants in version.sh (ARCH)

`<!-- vault-persona-start -->` and `<!-- vault-persona-end -->` are used in `lib/settings.sh` but are not defined as constants in `lib/version.sh`. All marker strings must be centralised.

**What to check:**

```bash
grep -n 'vault-persona-start\|vault-persona-end' /home/user/claude-vault/lib/settings.sh
grep -n 'VAULT_PERSONA_START\|VAULT_PERSONA_END'  /home/user/claude-vault/lib/version.sh
```

Expect: constants defined in `version.sh`, referenced in `settings.sh`. Current state: raw strings in `settings.sh` only.

**Current status:** OPEN (see Known Issues — ARCH-002).

#### ARCH-007 — Skill completeness: uninstall removes exactly what install adds

This is the complement to ARCH-001. The installed skill set and the uninstalled skill set must be symmetric. Test both directions:

- Install → list skills → uninstall → verify zero skills remain
- Uninstall on a fresh system (no prior install) → must exit cleanly, no errors

#### ARCH-008 — Constants consistency: version.sh markers used everywhere

```bash
grep -rn 'claude-vault-start\|claude-vault-end\|vault-settings-start\|vault-settings-end' \
  /home/user/claude-vault/ \
  --include='*.sh' \
  --exclude-dir='.git'
```

Every match must be inside `lib/version.sh` as the constant definition. Any match in `install.sh`, `uninstall.sh`, `configure.sh`, or the test suite is a WARN unless it is importing the constant.

#### ARCH-009 — Non-destructiveness of vault files

`memory.md` and `directives.md` in the vault directory must **never** be overwritten by any script after initial creation. They contain user data.

**Verification:**

```bash
echo "CANARY" >> "$HOME/.claude/vault/memory.md"
bash /home/user/claude-vault/install.sh   # reinstall
grep "CANARY" "$HOME/.claude/vault/memory.md"  # PASS: canary must survive
```

#### ARCH-010 — SKILL.md frontmatter completeness

All five skill files must have valid YAML frontmatter (opening and closing `---` delimiters and a `name` field):

```bash
for skill in load-memory save-memory note vault-edit setup; do
  file="/home/user/claude-vault/skills/$skill/SKILL.md"
  head -5 "$file"
  echo "---"
done
```

#### ARCH-011 — VERSION single source of truth

The version string must live only in the `VERSION` file at the repo root. No other file may hardcode it.

```bash
grep -rn '1\.0\.0' /home/user/claude-vault/ --include='*.sh' --include='*.md' \
  --exclude-dir='.git' | grep -v 'VERSION\|CHANGELOG'
```

Zero matches expected (aside from CHANGELOG.md which is exempt as a historical record).

---

### 3.3 Integration

Integration tests exercise the full install lifecycle end-to-end. These are automated in `qa/senior/integration.sh` (file not yet created — see section 5, note on missing files).

Each test below must be run in a fresh `qa/setup-env.sh` sandbox.

#### INT-001 — Fresh global install

```bash
source qa/setup-env.sh
bash /home/user/claude-vault/install.sh
```

Verify after completion:

| Artefact | Expected state |
|---|---|
| `$HOME/.claude/CLAUDE.md` | Contains `<!-- claude-vault-start -->` block |
| `$HOME/.claude/vault/memory.md` | Exists, non-empty |
| `$HOME/.claude/vault/directives.md` | Exists, non-empty |
| `$HOME/.claude/.vault-install` | Exists, contains `VAULT_PATH` and `CLAUDE_MD` keys |
| `$HOME/.claude/skills/load-memory/SKILL.md` | Exists |
| `$HOME/.claude/skills/save-memory/SKILL.md` | Exists |
| `$HOME/.claude/skills/note/SKILL.md` | Exists |
| `$HOME/.claude/skills/vault-edit/SKILL.md` | Exists |
| `$HOME/.claude/skills/setup/SKILL.md` | Exists |

#### INT-002 — Fresh project-scoped install

```bash
source qa/setup-env.sh
mkdir -p /tmp/qa-project
PROJECT_PATH=/tmp/qa-project bash /home/user/claude-vault/install.sh
```

Verify:

| Artefact | Expected state |
|---|---|
| `/tmp/qa-project/CLAUDE.md` | Contains vault block |
| `/tmp/qa-project/vault/memory.md` | Exists |
| `/tmp/qa-project/.gitignore` | Contains `/vault` entry |
| `$HOME/.claude/skills/*` | Skills still go to global skills dir |

#### INT-003 — Reinstall (settings-only)

After a fresh install (INT-001), run install again and choose the "settings only" option when prompted about an existing install. Verify:

- Vault files unchanged (canary test as in ARCH-009)
- Settings block in CLAUDE.md updated
- Skill files unchanged

#### INT-004 — Reinstall (full)

After a fresh install, run install again and choose full reinstall. Verify:

- CLAUDE.md vault block refreshed (only one block present)
- Vault files **not** overwritten
- All five skills present

#### INT-005 — Uninstall completeness

After a fresh install, run `bash /home/user/claude-vault/uninstall.sh`. Verify:

| Artefact | Expected state after uninstall |
|---|---|
| `$HOME/.claude/CLAUDE.md` vault block | Removed — no `<!-- claude-vault-start -->` in file |
| `$HOME/.claude/.vault-install` | Removed |
| `$HOME/.claude/skills/load-memory/` | Removed |
| `$HOME/.claude/skills/save-memory/` | Removed |
| `$HOME/.claude/skills/note/` | Removed (currently FAILS — BUG-001) |
| `$HOME/.claude/skills/vault-edit/` | Removed (currently FAILS — BUG-001) |
| `$HOME/.claude/skills/setup/` | Removed (currently FAILS — BUG-001) |
| `$HOME/.claude/vault/` | **Preserved** — user data must not be deleted |
| `$HOME/.claude/.vault-persona` | **Preserved** — user preference |

#### INT-006 — Persona setup: named persona

During install, choose the "named AI" path. Supply a name (e.g., `Nova`). Verify:

- `$HOME/.claude/.vault-persona` exists and contains `AI_NAME=Nova`
- `$HOME/.claude/vault/directives.md` contains the persona block with `Nova`
- Re-running install does NOT prompt for persona again (`.vault-persona` is write-once)

#### INT-007 — Persona setup: AI-chooses

During install, choose the "let AI choose its name" path. Verify:

- `.vault-persona` exists and contains `USER_PERSONA_TYPE=ai-choose` (or equivalent)
- `directives.md` contains the self-naming directive
- No `AI_NAME` key present in `.vault-persona`

#### INT-008 — Persona setup: skip

During install, choose to skip persona setup. Verify:

- `.vault-persona` exists (marks the question as answered)
- No persona block in `directives.md`

#### INT-009 — Cross-session persona guard

`.vault-persona` is written exactly once and never overwritten. Verify:

```bash
# After a full install with persona configured:
ORIGINAL=$(cat "$HOME/.claude/.vault-persona")
bash /home/user/claude-vault/install.sh   # reinstall
AFTER=$(cat "$HOME/.claude/.vault-persona")
[ "$ORIGINAL" = "$AFTER" ] && echo PASS || echo FAIL
```

#### INT-010 — Uninstall on clean system

```bash
source qa/setup-env.sh
# Do NOT run install first
bash /home/user/claude-vault/uninstall.sh
echo "Exit: $?"   # PASS: exit 0, no error output
```

---

### 3.4 Regression

The regression suite at `test/run.sh` contains **35 tests** across 8 function groups. Run it as:

```bash
bash /home/user/claude-vault/test/run.sh
```

All 35 must pass before any release. `qa/senior/regression.sh` delegates to this file.

#### What the 35 tests cover

| Group | Count | Functions tested |
|---|---|---|
| `read_current_settings` | 5 | Read role, length, confirm directive; empty-block behaviour |
| `write_settings_block` | 7 | Marker written, all directives written, no duplication, custom content preserved |
| `detect_vault` | 3 | Install config location, vault path round-trip, CLAUDE.md path round-trip |
| `uninstall — CLAUDE.md block removal` | 3 | Block removed, pre-block content preserved, post-block content preserved |
| `install config round-trip` | 2 | Vault path and CLAUDE.md path survive write/read |
| `list_plugins` | 3 | Finds plugin-a, finds plugin-b, skips dirs without `manifest.sh` |
| `install_plugin` | 3 | Skill installed to skills dir, template copied to vault, existing vault file not overwritten |
| `write_persona_block` | 9 | All persona paths: skip, empty, named (no user addr), named+user, ai-choose |

#### Gap analysis — what the unit tests do NOT cover

The following behaviours are not exercised by `test/run.sh` and require either the senior automated checks or manual testing:

| Gap | Where covered |
|---|---|
| Full install/uninstall lifecycle | INT-001 – INT-010 (this plan) |
| Sed injection via user input | SEC-001 (security.sh) |
| Path traversal | SEC-002 (security.sh) |
| Source injection via .vault-install | SEC-003 (security.sh) |
| File permissions | SEC-004 (security.sh) |
| Uninstall skill completeness | ARCH-001 (architecture.sh) |
| Hardcoded markers in uninstall.sh | ARCH-002 (architecture.sh) |
| configure.sh skill refresh | ARCH-005 (architecture.sh) |
| Persona marker constants | ARCH-006 (architecture.sh) |
| Skill functionality via Claude | Section 3.6 (manual) |
| Performance targets | Section 3.5 |
| Special character edge cases | Section 3.7 |

---

### 3.5 Performance

Performance tests are referenced in `qa/run-senior.sh` as `qa/senior/performance.sh` (Check 4), but this file does not yet exist. Until it is created, run these checks manually.

#### PERF-001 — Install script execution time

Target: **under 10 seconds** on any supported platform.

```bash
source qa/setup-env.sh
time bash /home/user/claude-vault/install.sh < /dev/null   # non-interactive mode
```

Measure wall clock time. Fail if `real` exceeds 10s.

#### PERF-002 — Test suite execution time

Target: **under 5 seconds** on any supported platform.

```bash
time bash /home/user/claude-vault/test/run.sh
```

#### PERF-003 — Idempotent reinstall performance

A reinstall (second call to `install.sh`) must not be materially slower than a fresh install. The awk-based block replacement for CLAUDE.md should be O(n) in file size.

```bash
source qa/setup-env.sh
bash /home/user/claude-vault/install.sh < /dev/null   # prime
time bash /home/user/claude-vault/install.sh < /dev/null   # measure reinstall
```

Fail if reinstall takes more than 2x the fresh install time.

#### PERF-004 — Large CLAUDE.md handling

A user may have a large CLAUDE.md (e.g., 10,000 lines of existing content). The vault block injection must not degrade quadratically.

```bash
source qa/setup-env.sh
python3 -c "print('x ' * 50 + '\n') * 10000" > "$HOME/.claude/CLAUDE.md"
time bash /home/user/claude-vault/install.sh < /dev/null
```

---

### 3.6 User Experience — Skill Functionality

These tests require a live Claude Code session with claude-vault installed. They are inherently semi-manual. Record the Claude Code version, model name, and a one-line outcome for each.

**Setup:**

```bash
# Real install (not sandboxed — use a dedicated test machine or a test user account)
bash /home/user/claude-vault/install.sh
claude   # open a session
```

#### UX-001 — /load-memory

Trigger: `/load-memory`

Expected: Claude reads `memory.md` and `directives.md` from the vault, then responds with a confirmation message containing the phrase "I know kung fu" (or the configured variant).

Check:
- The response acknowledges vault content was loaded
- If `memory.md` has a current project section, Claude references it
- If `memory.md` is empty, Claude notes it gracefully (no crash or confused response)

#### UX-002 — /save-memory

Trigger: After doing some work in a session (make a few architectural decisions), run `/save-memory`

Expected: Claude distills the session context into `memory.md` and responds with a confirmation containing the phrase "Bonfire lit, memory preserved" (or configured variant).

Check:
- `memory.md` is updated — `diff` the file before and after
- Existing content in `memory.md` is preserved or intelligently merged, not overwritten wholesale
- The response does not contain raw JSON or bash output
- Decision trigger: if `memory.md` exceeds 80 lines, Claude should distill/compress existing content rather than appending

"Good" distillation looks like: key architectural decisions preserved as bullets, completed tasks summarised in past tense, next steps clear. "Bad" distillation looks like: verbatim conversation transcript appended, or all prior context erased.

#### UX-003 — /note [text]

Trigger: `/note Decided to use PostgreSQL for the session store`

Expected: Single line added to `memory.md` (or an appropriate section of it). Response contains "Noted." Claude does not re-summarise or restructure the file.

Check:
- The note text appears verbatim in `memory.md`
- No other lines in `memory.md` are modified
- `/note` with no argument: Claude prompts for the note text rather than erroring

#### UX-004 — /vault-edit

Trigger: `/vault-edit`

Expected: Claude opens or presents the vault files (`memory.md`, `directives.md`) for review and editing. User can add a new standing rule.

Check:
- Claude offers to add/modify/remove entries in both files
- Changes are written to disk (verify with `cat ~/.claude/vault/directives.md`)
- Claude does not overwrite the entire file on small edits

#### UX-005 — /setup

Trigger: `/setup`

Expected: Claude presents current vault settings (role, response-length preference, confirm directive) and offers to change them.

Check:
- Current settings are read correctly from CLAUDE.md settings block
- A setting change is written back inside the `<!-- vault-settings-start -->` / `<!-- vault-settings-end -->` markers
- Content outside the markers is not touched
- The response does not expose raw file contents unprompted

#### UX-006 — Memory distillation quality at 80-line threshold

Prepare a `memory.md` that is exactly 85 lines long, then run `/save-memory` with a session that adds more content.

Observe: does Claude compress the existing content, or append blindly past the threshold?

Pass criterion: resulting `memory.md` is no longer than ~80 lines, and no previously-recorded decision is lost without a summary.

#### UX-007 — Decision triggers fire correctly

The `save-memory` skill includes trigger conditions (e.g., "at the end of a productive session", "when asked to save"). Verify that Claude does not spontaneously run save-memory without being asked.

Test: Work for several exchanges without invoking `/save-memory`. Verify Claude does not save to disk unprompted.

---

### 3.7 Edge Cases & Error Handling

#### EDGE-001 — Special characters in USER_NAME

At install time, when prompted for your name, enter each of the following in separate test runs:

| Input | Expected outcome |
|---|---|
| `O'Brien` | Apostrophe preserved literally in vault files |
| `Alice & Bob` | Ampersand preserved; sed not corrupted (currently FAILS — SEC-001) |
| `Tom/Jerry` | Slash preserved; sed not corrupted (currently FAILS — SEC-001) |
| `José` | Unicode preserved correctly |
| `` (empty) | Install prompts again or uses a default, does not write an empty name |

#### EDGE-002 — Special characters in PROJECT_NAME

Same matrix as EDGE-001 but for the project name prompt.

#### EDGE-003 — Empty input on required prompts

At each interactive prompt in `install.sh`, press Enter with no input. The script must either re-prompt or use a documented default. It must not write an empty value into config files.

Prompts to test:
- User name
- Project name
- Install scope (global vs project)
- Project path (if project-scoped)

#### EDGE-004 — Corrupted .vault-install

```bash
source qa/setup-env.sh
bash /home/user/claude-vault/install.sh   # fresh install
echo "GARBAGE$$&&CORRUPTED" >> "$HOME/.claude/.vault-install"
# Now call detect_vault
source /home/user/claude-vault/lib/vault.sh
detect_vault   # must not crash; must return a usable path or a clear error
```

#### EDGE-005 — Missing vault directory when skill runs

```bash
rm -rf "$HOME/.claude/vault"
# Open a Claude Code session and run /load-memory
```

Expected: Claude reports that the vault directory is missing with a helpful message, and suggests running `/setup` or reinstalling. It must not output a bash traceback or raw error.

#### EDGE-006 — Vault file exceeds 80 lines

Create a `memory.md` with 120 lines:

```bash
python3 -c "
for i in range(120):
    print(f'- Decision {i}: use approach {i} because reason {i}')
" > "$HOME/.claude/vault/memory.md"
```

Then run `/save-memory`. The skill's instructions say to distill harder when the file is long. Verify the output file is compressed and within a reasonable bound, not a 120+ line append.

#### EDGE-007 — Empty vault files

```bash
> "$HOME/.claude/vault/memory.md"
> "$HOME/.claude/vault/directives.md"
```

Run `/load-memory`. Claude must acknowledge empty vault gracefully ("vault is empty" or equivalent) and not fail silently or hallucinate content.

#### EDGE-008 — Missing sections in memory.md

A valid `memory.md` has structured sections (Current Project, Decisions, Next Steps, etc.). Write a `memory.md` with no sections — just freeform text:

```bash
echo "Some random notes without any markdown headers" > "$HOME/.claude/vault/memory.md"
```

Run `/save-memory`. Claude must not crash or produce structurally broken output.

---

## 4. Known Issues

Issues confirmed during development of v1.0.0. Each entry includes the test case that surfaces it.

---

### BUG-001 — Uninstall orphans 3 of 5 skills

**Severity:** BUG  
**File:** `uninstall.sh`  
**Surfaces in:** INT-005, ARCH-001  

`uninstall.sh` only removes `~/.claude/skills/load-memory/` and `~/.claude/skills/save-memory/`. The following installed skill directories are not removed:

- `~/.claude/skills/note/`
- `~/.claude/skills/vault-edit/`
- `~/.claude/skills/setup/`

These three skills remain active in Claude Code after uninstall, which is incorrect behaviour.

**Reproduction:**

```bash
source qa/setup-env.sh
bash /home/user/claude-vault/install.sh
bash /home/user/claude-vault/uninstall.sh
ls "$HOME/.claude/skills/"   # shows: note/ vault-edit/ setup/ — all should be gone
```

**Fix:** Add `rm -rf` calls for all five skill directories in `uninstall.sh`, or loop over `VAULT_SKILLS` array.

---

### BUG-002 — Uninstall hardcodes marker strings instead of using constants

**Severity:** BUG  
**File:** `uninstall.sh`  
**Surfaces in:** ARCH-002  

`uninstall.sh` contains hardcoded marker strings to identify and remove the vault block from CLAUDE.md. It does not source `lib/version.sh` and does not use `VAULT_CLAUDE_START` / `VAULT_CLAUDE_END`. If the marker strings in `version.sh` are ever updated (e.g., for a major version bump), the uninstall script will fail to find and remove the block.

**Verification:**

```bash
grep 'claude-vault-start\|claude-vault-end' /home/user/claude-vault/uninstall.sh
# Returns hardcoded strings instead of variable references
```

**Fix:** Source `lib/version.sh` at the top of `uninstall.sh` and replace hardcoded strings with `$VAULT_CLAUDE_START` / `$VAULT_CLAUDE_END`.

---

### SEC-001 — USER_NAME / PROJECT_NAME used directly in sed replacement

**Severity:** HIGH  
**File:** `install.sh`  
**Surfaces in:** SEC-001, EDGE-001, EDGE-002  

User-supplied name and project strings are interpolated directly into `sed` `s/…/…/` replacement expressions. The `&` character in sed replacement means "matched text" — entering `Alice & Bob` will silently produce `Alice Alice & Bob Bob`. A `/` will break the sed expression delimiter, causing a syntax error.

**Reproduction:**

```bash
source qa/setup-env.sh
# At the name prompt, enter: Alice & Bob
bash /home/user/claude-vault/install.sh
grep "Alice" "$HOME/.claude/vault/memory.md"   # shows corrupted value
```

**Fix:** Sanitise before sed substitution:

```bash
SAFE_NAME=$(printf '%s' "$USER_NAME" | sed 's/[&/\]/\\&/g')
```

Or switch to `awk -v name="$USER_NAME"` which handles literal string substitution without metacharacter issues.

---

### SEC-002 — PROJECT_PATH not canonicalised before use

**Severity:** HIGH  
**File:** `install.sh`  
**Surfaces in:** SEC-002  

When the user selects project-scoped install and enters a path, the value is used directly without calling `realpath` or `readlink -f`. A path containing `..` components can escape the intended project directory.

**Fix:**

```bash
PROJECT_PATH=$(realpath "$PROJECT_PATH" 2>/dev/null) || {
  echo "Error: invalid project path" >&2
  exit 1
}
```

---

### ARCH-001 — configure.sh does not refresh or install new skills

**Severity:** ARCH  
**File:** `configure.sh`  
**Surfaces in:** ARCH-005  

`configure.sh` handles settings-only reconfiguration but does not call `install_plugin` for any skill. Users who run `configure.sh` after upgrading the repo will not receive new skills that were added in the newer version. The upgrade path is silently incomplete.

**Fix:** Add a skill installation loop to `configure.sh` that mirrors the one in `install.sh`.

---

### ARCH-002 — Persona marker strings not defined in version.sh

**Severity:** ARCH  
**Files:** `lib/settings.sh`, `lib/version.sh`  
**Surfaces in:** ARCH-006  

The marker strings `<!-- vault-persona-start -->` and `<!-- vault-persona-end -->` are hardcoded in `lib/settings.sh:write_persona_block()`. They are not exported as constants from `lib/version.sh`. This means:

- Uninstall or any future script that needs to find or remove the persona block must rediscover the strings
- A rename of the markers requires changes in multiple places

**Fix:** Add to `lib/version.sh`:

```bash
VAULT_PERSONA_START="<!-- vault-persona-start -->"
VAULT_PERSONA_END="<!-- vault-persona-end -->"
```

Then reference `$VAULT_PERSONA_START` / `$VAULT_PERSONA_END` in `settings.sh`.

---

## 5. Test Execution Checklist

Run a full QA pass in this order. All steps must complete before signing off.

> **Note:** `qa/senior/integration.sh` and `qa/senior/performance.sh` are referenced by `qa/run-senior.sh` but do not yet exist. Steps 3 and 4 below must be run manually until those files are created.

```
[ ] 0. Confirm environment
       bash --version | head -1           # must be 3.2+ or 5+
       echo $QA_HOME                      # must be empty (not yet set)

[ ] 1. Set up sandbox
       source /home/user/claude-vault/qa/setup-env.sh
       echo $QA_HOME                      # must be non-empty /tmp/... path

[ ] 2. Run automated regression suite
       bash /home/user/claude-vault/test/run.sh
       # Expected: 35/35 tests pass

[ ] 3. Run senior automated checks
       bash /home/user/claude-vault/qa/run-senior.sh
       # Note: integration.sh and performance.sh will fail (files missing)
       # Check 0 (regression), Check 1 (security), Check 2 (architecture) must pass

[ ] 4. Manual integration tests
       # Execute INT-001 through INT-010 per section 3.3
       # Each test starts with: source qa/setup-env.sh (fresh sandbox)
       # Record PASS/FAIL against each INT-XXX ID

[ ] 5. Manual security verification
       # Execute SEC-001 through SEC-008 manual steps per section 3.1
       # For SEC-001 and SEC-002: these are known OPEN findings — record as FAIL

[ ] 6. Manual performance tests (PERF-001 through PERF-004)
       # Run timing commands per section 3.5
       # Record wall-clock times

[ ] 7. Skill smoke tests (requires live Claude Code session)
       # Execute UX-001 through UX-007 per section 3.6
       # Record Claude Code version, model, and outcome for each

[ ] 8. Edge case tests
       # Execute EDGE-001 through EDGE-008 per section 3.7

[ ] 9. Tear down sandbox
       bash /home/user/claude-vault/qa/teardown.sh
       echo $QA_HOME   # should still be set in your shell — that is expected
                       # the directory is deleted; the variable lingers
```

**Reference to manual test cases:** See `qa/manual/MANUAL-TESTS.md` (to be created) for step-by-step procedures for all manual checks above.

---

## 6. Pass / Fail Criteria

### Release gate — all of the following are required to ship

| Criterion | Threshold | Notes |
|---|---|---|
| Regression suite | **35/35 pass** | Zero tolerance — a failing unit test blocks the release |
| Senior security checks | **All automated SEC checks pass** | Manual HIGH findings must also be resolved |
| Senior architecture checks | **All automated ARCH checks pass** | BUG-level findings must be resolved |
| HIGH security findings | **Zero open** | SEC-001 and SEC-002 are currently OPEN — release is blocked until fixed |
| BUG-level architecture findings | **Zero open** | BUG-001 and BUG-002 are currently OPEN — release is blocked until fixed |
| Integration tests INT-001 – INT-010 | **All pass** | Any failure blocks release |
| Performance: install script | **< 10 seconds** | Measured on a clean sandbox |
| Performance: test suite | **< 5 seconds** | Measured on the host machine |
| Manual skill smoke tests UX-001 – UX-005 | **All pass** | UX-006 and UX-007 are advisory (model-dependent) |

### Advisory criteria — failures are tracked but do not block release

| Criterion | Notes |
|---|---|
| ARCH-level findings (non-BUG) | Tracked; targeted for next minor release |
| UX-006, UX-007 | Model output quality — tracked as issues, not blockers |
| WARN-level findings | Informational; not release blockers |
| PERF-003, PERF-004 | Advisory performance targets |
| EDGE cases with known-open bugs | Already tracked as SEC-001/BUG-001 etc. |

### Exceptional overrides

A release may proceed with open ARCH (non-BUG) findings if:

1. The finding has a filed issue with a milestone
2. The release notes document the limitation explicitly
3. The responsible maintainer signs off in writing

No override is permitted for open HIGH security findings or BUG-level architecture findings.

---

## 7. Reporting

### Severity classification

#### Security findings

| Level | Definition | Example |
|---|---|---|
| **HIGH** | Exploitable with user-supplied input; data corruption or privilege escalation possible | SEC-001 (sed injection), SEC-002 (path traversal) |
| **MEDIUM** | Exploitable under specific conditions; limited blast radius | SEC-004 (file permissions wider than 600) |
| **LOW** | Defence-in-depth issue; no direct exploitation path | SEC-006 (temp file not cleaned up) |
| **INFO** | Best practice violation; no security impact | SEC-007 (eval absent — informational pass) |

#### Architecture findings

| Level | Definition | Example |
|---|---|---|
| **BUG** | Functional breakage — install/uninstall produces incorrect result | BUG-001 (skills not removed), BUG-002 (hardcoded markers) |
| **ARCH** | Design inconsistency; does not break today but will cause failures under future changes | ARCH-001 (configure.sh), ARCH-002 (persona markers) |
| **WARN** | Code quality / maintainability concern; no functional impact | Hardcoded strings that match constants |

### Finding format

File each finding as:

```
ID:          [SEC|BUG|ARCH|WARN]-NNN
Title:       One-line description
Severity:    HIGH | MEDIUM | LOW | INFO | BUG | ARCH | WARN
File:        Affected file(s) with line numbers
Surfaces in: Test case ID(s) that reproduce it
Description: What is wrong and why it matters
Reproduction: Exact commands to reproduce
Expected:    What should happen
Actual:      What happens today
Fix:         Recommended resolution (optional but encouraged)
Status:      OPEN | IN PROGRESS | FIXED | WONTFIX
```

### Reporting location

- File findings as issues in the project repository with the appropriate severity label
- During a QA pass, record all findings in a dated run report: `qa/runs/YYYY-MM-DD.md`
- Reference the TEST-PLAN.md version and the software version under test in the run report header
- Link each finding to the corresponding test case ID from this document

### Escalation

HIGH security findings must be communicated to the project maintainer within 24 hours of discovery, regardless of whether a full QA pass is in progress. Do not wait for a complete run report.
