# Changelog

All notable changes are documented here.
Format follows [Semantic Versioning](https://semver.org/).

---

## [1.1.0] — 2026-06-19

### Added
- `/load-memory` skill — reload all vault files mid-session
- `/save-memory` skill — checkpoint the current session into `memory.md`
- `/note` skill — quick-capture a single decision without a full checkpoint
- `/update` skill and `update.sh` — check the installed version against GitHub and apply updates
- One-time AI persona setup (name your assistant), stored in `~/.claude/.vault-persona`
- Memory-stewardship directives — Claude proactively suggests `/note` and `/save-memory` at decision points
- `Next up` section in the `memory.md` template
- GitHub Actions CI — runs `test/run.sh` on every push and pull request, with a status badge in the README

### Changed
- Reinstall menu now offers "use existing setup" (no questions) vs "change setup"
- Designer role preset is now behavioral (anchor on the user and problem, give options with trade-offs) instead of a list of design-systems topics
- README documents all six skills, persona setup, and the update flow
- QA suite moved to the `qa/testing` branch to keep the product repo lean

### Fixed
- `uninstall.sh` now removes `~/.claude/.vault-persona` — previously orphaned, which silently broke the persona prompt on reinstall
- "Use existing setup" install path is now fully non-interactive — it no longer aborts when `.vault-persona` is absent, unblocking `update.sh`
- Normalized executable bits across user-facing and helper scripts
- Replaced maintainer-derived test fixture data with neutral placeholders

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
