# Changelog

All notable changes are documented here.
Format follows [Semantic Versioning](https://semver.org/).

---

## [2.0.0] — 2026-06-17

### Added

**Memory skills**
- `/load-memory` — instructs Claude to read `memory.md` and directives at session start; prints the iconic "🧠 I know kung fu." confirmation
- `/save-memory` — instructs Claude to write open items back to `memory.md` and close the session with "🔥 Bonfire lit, memory preserved."
- `/note` — quick capture: appends a timestamped note to `memory.md` without a full save cycle; acknowledges with "📌 Noted."

**Update flow**
- `/update` skill — read-only skill that reads `~/.claude/.vault-install` (VERSION, REPO_PATH, INSTALL_DATE) and reports the current version with the exact command to run `update.sh`
- `update.sh` — one-command updater: fetches `origin/main`, compares versions, shows the git log of incoming commits, prompts for confirmation, pulls, and re-runs `install.sh` in "use existing" mode

**Persona setup**
- One-time persona questionnaire at install: AI name, role, communication style, extra context
- Persona answers written to `~/.claude/.vault-persona` — presence of this file means "never ask again"
- Persona block injected into `CLAUDE.md` between `<!-- vault-persona-start/end -->` markers; idempotent on reinstall

**Reinstall UX**
- "Use existing setup" path on reinstall: detects existing `.vault-install`, displays stored name/project/scope, and offers a one-keystroke option (press `1`) that skips all questions and only refreshes skills
- Stored metadata expanded: `USER_NAME`, `PROJECT_NAME`, `PROJECT_PATH`, `REPO_PATH` now saved to `.vault-install`

**QA suite**
- `qa/senior/integration.sh` — 10 automated integration test cases covering full install, reinstall (use-existing and redo), uninstall, scope variants, persona, edge cases, and the complete `update.sh` flow (up-to-date, accept update, decline update) using isolated local git repos
- `qa/senior/architecture.sh` — 11 architecture checks: uninstall completeness, marker constant coverage, DRY analysis, function length, skill frontmatter, version source of truth
- Manual test plan (`qa/senior/`) documenting 12 Claude Code skill and trigger tests requiring a live session
- `docs/diagram.html` — visual architecture diagram of the full vault system

### Changed
- `install.sh` done message updated to mention `/update` and `./update.sh`
- `install.sh` vault block in `CLAUDE.md` now references `/update` alongside existing skills
- `uninstall.sh` skill removal loop now includes `update` (was missing `load-memory`, `save-memory`, `note`, `update`)
- `uninstall.sh` help text updated to list all 6 skills
- `write_install_config()` accepts 8 parameters (added `user_name`, `project_name`, `project_path`, `repo_path`)

### Fixed
- `list_plugins()` crashed `install.sh` under `set -e`: `|| return` returned the exit code of the preceding `[ -d ]` check (1 when dir absent), killing the shell; fixed to `|| return 0`
- `ask_persona_setup()` crashed under `set -e`: `[ -n "$AI_NAME" ] && echo "..."` returns 1 when `AI_NAME` is empty; changed to explicit `if/then` blocks
- `uninstall.sh` removed only 2 skills (`vault-edit`, `setup`) despite `install.sh` installing 6; all 6 now removed on uninstall

---

## [1.0.0] — 2026-05-28

### Added
- `VERSION` file — single source of truth for vault version
- `lib/version.sh` — version constant sourced by all scripts
- `lib/vault.sh` — vault detection and install config helpers
- `lib/plugins.sh` — plugin discovery and installation
- `uninstall.sh` — clean removal of vault block, skills, and install config
- `~/.claude/.vault-install` — install config enabling auto-detection across sessions
- Plugin architecture — standardised `plugins/` folder with manifest and install convention
- Skill frontmatter for `/vault-edit` and `/setup`
- `test/run.sh` — automated test suite

### Fixed
- `configure.sh` "keep current value" was broken — pressing Enter now preserves existing settings
- `write_settings_block()` injected after line 1 (fragile) — now locates `# Directives` heading by content
- `configure.sh` could not auto-detect project-scoped vaults — now uses install config

### Changed
- `install.sh` writes install config after successful install
- `configure.sh` auto-detects vault before prompting for path
- `ask_settings()` accepts existing `directives.md` path and shows current values before each prompt
