# Changelog

All notable changes are documented here.
Format follows [Semantic Versioning](https://semver.org/).

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
