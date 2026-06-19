# Claude Vault — QA

Two modes: automated (senior) and manual (junior). Both use an isolated environment that never touches your real `~/.claude`.

---

## Quick start

```bash
# 1. Get on the QA branch
git checkout qa/testing

# 2. Source the environment (overrides $HOME to a temp dir)
source qa/setup-env.sh

# 3a. Run the full automated senior suite
bash qa/run-senior.sh

# 3b. OR run individual checks
bash qa/senior/regression.sh
bash qa/senior/security.sh
bash qa/senior/architecture.sh
bash qa/senior/integration.sh
bash qa/senior/performance.sh

# 4. Clean up when done
bash qa/teardown.sh
```

The environment is **sandboxed**: `$HOME` is set to a temp directory for the duration of the session. `install.sh`, `configure.sh`, and `uninstall.sh` all write to that temp dir — your real vault and `~/.claude` are never touched.

---

## Manual tests

Open `qa/manual/MANUAL-TESTS.md`. Each test case has:
- Preconditions
- Step-by-step instructions
- Expected result (observable, specific)
- Pass/Fail checkbox
- Notes field

Run manual tests on a fresh terminal after `source qa/setup-env.sh`.

---

## Test plan overview

See `qa/manual/TEST-PLAN.md` for what a senior tester checks: security, architecture, integration, performance, regression.

---

## Re-running cleanly

Each run of `source qa/setup-env.sh` creates a new temp dir, so every run starts fresh. Run it again to reset.

```bash
bash qa/teardown.sh   # remove current temp dir
source qa/setup-env.sh  # fresh start
```
