#!/usr/bin/env bash
# Architecture review — design, consistency, completeness, and code quality.
# Reports [BUG] for real defects, [ARCH] for design violations, [WARN] for smells.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
BUGS=0
WARN=0

pass() { echo "  ✓  $1"; PASS=$((PASS+1)); }
bug()  { echo "  ✗  [BUG]  $1"; BUGS=$((BUGS+1)); }
arch() { echo "  ⚠  [ARCH] $1"; WARN=$((WARN+1)); }
warn() { echo "  ~  [WARN] $1"; WARN=$((WARN+1)); }
info() { echo "     [INFO] $1"; }

echo ""
echo "── ARCH-001: Uninstall removes ALL installed skills ────────────────────────"
echo ""
# install.sh now installs 5 skills. uninstall.sh only removes 2.
installed=$(grep 'mkdir -p.*SKILLS_DEST' "$REPO/install.sh" | grep -v '#' | wc -l | tr -d ' ')
removed=$(grep 'for skill in' "$REPO/uninstall.sh" | grep -oP '(?<=in ).*(?=;)' | tr ' ' '\n' | grep -v '^$' | wc -l | tr -d ' ')

info "Skills installed by install.sh: $installed"
info "Skills removed by uninstall.sh: $removed"

if [ "$installed" -gt "$removed" ]; then
  bug "ARCH-001 uninstall.sh removes $removed skills but install.sh installs $installed."
  info "Missing from uninstall: load-memory, save-memory, note"
  info "Fix: update 'for skill in ...' loop in uninstall.sh to include all 5 skills."
else
  pass "ARCH-001 uninstall removes all installed skills"
fi

echo ""
echo "── ARCH-002: Uninstall uses hardcoded markers instead of constants ──────────"
echo ""
# version.sh defines VAULT_CLAUDE_START/END. uninstall.sh sources version.sh
# but then hardcodes <!-- claude-vault-start --> directly in the awk script.
if grep -q 'VAULT_CLAUDE_START\|VAULT_CLAUDE_END' "$REPO/uninstall.sh"; then
  pass "ARCH-002 uninstall.sh uses version.sh marker constants"
else
  arch "ARCH-002 uninstall.sh sources version.sh but doesn't use VAULT_CLAUDE_START/END."
  info "Markers are hardcoded in the awk script instead. If marker strings change,"
  info "uninstall.sh will silently fail to remove the block."
  info "Fix: replace hardcoded <!-- claude-vault-start/end --> with \$VAULT_CLAUDE_START/END."
fi

echo ""
echo "── ARCH-003: Uninstall message is out of date ──────────────────────────────"
echo ""
if grep 'vault-edit and /setup' "$REPO/uninstall.sh" | grep -q .; then
  bug "ARCH-003 uninstall.sh help text says 'Skills /vault-edit and /setup' — 3 new skills missing."
  info "Fix: update the 'This will remove' section to list all 5 skills."
else
  pass "ARCH-003 uninstall message lists all skills"
fi

echo ""
echo "── ARCH-004: configure.sh does not refresh skills ──────────────────────────"
echo ""
if grep -q 'cp.*skills\|SKILLS_DEST' "$REPO/configure.sh"; then
  pass "ARCH-004 configure.sh refreshes skills"
else
  arch "ARCH-004 configure.sh only updates settings — does not install new skills."
  info "If a user installs v1.0 then pulls v1.1 (with new skills) and runs configure.sh,"
  info "the new skills will not be installed. They would need to run install.sh instead."
  info "Fix: add skill copy block to configure.sh, or add a note to the docs."
fi

echo ""
echo "── ARCH-005: Input validation on scope selection ───────────────────────────"
echo ""
# read -p "Enter 1 or 2: " INSTALL_SCOPE — if user enters 3, "abc", or empty,
# the if/else logic falls through to global scope silently with no error.
if grep -A5 'INSTALL_SCOPE' "$REPO/install.sh" | grep -qE '^\s*(else|esac|invalid|unknown)'; then
  pass "ARCH-005 scope input has fallback/validation"
else
  warn "ARCH-005 INSTALL_SCOPE accepts any input; invalid values silently default to global."
  info "If user types '3' or 'yes', install proceeds as global with no warning."
  info "Fix: add explicit validation or an error on unexpected input."
fi

echo ""
echo "── ARCH-006: Marker constants coverage ─────────────────────────────────────"
echo ""
# Check that all scripts that use vault markers go through the constants
hardcoded=$(grep -rn '<!-- claude-vault-start\|<!-- claude-vault-end\|<!-- vault-settings-start\|<!-- vault-settings-end' \
  "$REPO/install.sh" "$REPO/configure.sh" "$REPO/uninstall.sh" "$REPO/lib/" \
  2>/dev/null | grep -v 'version.sh' | wc -l | tr -d ' ')

if [ "$hardcoded" -gt 0 ]; then
  warn "ARCH-006 $hardcoded hardcoded marker string(s) found outside version.sh."
  grep -rn '<!-- claude-vault-start\|<!-- claude-vault-end\|<!-- vault-settings-start\|<!-- vault-settings-end' \
    "$REPO/install.sh" "$REPO/configure.sh" "$REPO/uninstall.sh" "$REPO/lib/" \
    2>/dev/null | grep -v 'version.sh' | while IFS= read -r line; do
    info "$line"
  done
else
  pass "ARCH-006 all marker strings go through version.sh constants"
fi

echo ""
echo "── ARCH-007: Vault persona marker constants missing from version.sh ─────────"
echo ""
if grep -q 'vault-persona-start\|VAULT_PERSONA' "$REPO/lib/version.sh"; then
  pass "ARCH-007 vault-persona markers defined in version.sh"
else
  arch "ARCH-007 vault-persona markers (<!-- vault-persona-start/end -->) are not in version.sh."
  info "They are hardcoded in lib/settings.sh write_persona_block only."
  info "Minor for now (only one writer), but inconsistent with the other markers."
  info "Fix: add VAULT_PERSONA_START/END to version.sh."
fi

echo ""
echo "── ARCH-008: DRY — test assert helpers duplicated ──────────────────────────"
echo ""
# assert_contains / assert_not_contains / pass / fail are in test/run.sh.
# The QA senior scripts define their own. This is intentional (QA is separate)
# but worth noting for maintenance.
info "ARCH-008 test/run.sh and qa/senior/ each define their own assert helpers."
info "Not a defect — QA is intentionally separate. But if assert logic changes,"
info "both places need updating. Consider a shared qa/lib/assert.sh."
pass "ARCH-008 duplication is intentional and scoped (noted for maintenance)"

echo ""
echo "── ARCH-009: Function length — write_settings_block ───────────────────────"
echo ""
fn_lines=$(awk '/^write_settings_block\(\)/{found=1} found{count++} /^\}$/{if(found){print count; found=0; count=0}}' \
  "$REPO/lib/settings.sh" | head -1)
if [ -n "$fn_lines" ] && [ "$fn_lines" -gt 60 ]; then
  warn "ARCH-009 write_settings_block is $fn_lines lines. Consider splitting into write_block_content + inject_block."
else
  pass "ARCH-009 write_settings_block length: ${fn_lines:-unknown} lines (acceptable)"
fi

echo ""
echo "── ARCH-010: All skill SKILL.md files have frontmatter ─────────────────────"
echo ""
missing=0
for f in "$REPO/skills"/*/SKILL.md; do
  if ! head -1 "$f" | grep -q '^---'; then
    echo "  Missing frontmatter: $f"
    missing=$((missing+1))
  fi
done
if [ "$missing" -eq 0 ]; then
  pass "ARCH-010 all SKILL.md files have YAML frontmatter"
else
  bug "ARCH-010 $missing SKILL.md file(s) missing frontmatter (---)"
fi

echo ""
echo "── ARCH-011: VERSION file is single source of truth ───────────────────────"
echo ""
version_count=$(grep -rn 'VAULT_VERSION\s*=\s*"' "$REPO/lib/" "$REPO/install.sh" 2>/dev/null | \
  grep -v 'version.sh\|VAULT_VERSION="$' | wc -l | tr -d ' ')
if [ "$version_count" -eq 0 ]; then
  pass "ARCH-011 version string only defined in VERSION file (via version.sh)"
else
  warn "ARCH-011 version string hardcoded in $version_count place(s) outside version.sh"
fi

echo ""
echo "────────────────────────────────────────────────────────────────────────────"
printf "  Architecture results: %d passed  %d warnings  %d bugs\n" "$PASS" "$WARN" "$BUGS"
echo "────────────────────────────────────────────────────────────────────────────"
echo ""
