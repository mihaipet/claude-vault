---
name: update
description: Check your installed claude-vault version and get the command to update it.
---

# /update — Check your vault version

Use this skill to see what version of claude-vault you have installed and how to update it.

---

## What Claude will do

1. Read `~/.claude/.vault-install` for `VERSION`, `REPO_PATH`, and `INSTALL_DATE`
2. Report your current version and when it was installed
3. Give you the exact terminal command to check for and apply updates

---

## Rules for this skill

- Read `~/.claude/.vault-install` — it contains `VERSION`, `REPO_PATH`, and `INSTALL_DATE`
- Report current version and install date clearly
- If `REPO_PATH` is set in the config, give the user this exact command to run in their terminal:
  `bash $REPO_PATH/update.sh`
- If `REPO_PATH` is not set (older install), tell the user to navigate to their claude-vault repo and run `bash update.sh`
- Never modify any files during this skill — read-only
- The actual update (git pull + reinstall) happens in the terminal, not inside Claude Code
- If `.vault-install` does not exist, tell the user to run `install.sh` first
