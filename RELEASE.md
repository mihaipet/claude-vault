# Release checklist

Every change that lands on `main` is treated as a release. Before merging/pushing,
walk this checklist. Skip an item only when it genuinely doesn't apply, and say so.

## 1. Code & tests
- [ ] `bash test/run.sh` passes locally (37/0 or higher)
- [ ] New behavior has a test; fixed bugs have a regression test
- [ ] CI is green after push (GitHub Actions `tests` workflow)

## 2. Versioning (Semantic Versioning)
- [ ] Bump `VERSION`:
  - **patch** (x.y.Z) — bug fixes, docs, internal cleanup, no behavior change
  - **minor** (x.Y.0) — new features, backward-compatible
  - **major** (X.0.0) — breaking change to install layout, file format, or commands
- [ ] `lib/version.sh` reads `VERSION`, so nothing else needs editing for the bump

## 3. Changelog
- [ ] Add a `CHANGELOG.md` entry for the new version (dated), grouped into
      **Added / Changed / Fixed**, in user-facing language

## 4. Docs & descriptions
- [ ] `README.md` updated if commands, skills, install flow, or file layout changed
- [ ] GitHub repo description updated if the one-line pitch changed (`gh repo edit --description`)
- [ ] Skill `SKILL.md` files and `templates/` updated if their behavior changed

## 5. Commits & push
- [ ] One logical change per commit, clear messages
- [ ] Push to `main`; confirm CI green
- [ ] If the change is releasable on its own, the version bump + changelog can be its
      own `release: x.y.z` commit

> Note: the `VERSION` file is what `update.sh` compares against the remote to decide
> whether users see an update. If you ship user-facing changes without bumping it,
> `/update` will wrongly report "up to date." Never skip step 2 for a real change.
