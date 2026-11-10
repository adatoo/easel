# ADR-0005: GitHub-hosted runners only; shared workflows are vendored

**Status:** Accepted
**Date:** 2026-11-10
**Deciders:** project owner

## Context

Easel is public (ADR-0004). Two things the engineering standards expect don't survive that, as
Silicon Wallet found (its ADR-0007):

- **Self-hosted runners.** In a public repo, anyone can open a pull request from a fork, and the
  workflow files in that PR are the ones that run. A fork can change `runs-on` to any label the
  repo has, so nothing in our own YAML can keep a stranger's code off the Mac mini.
- **Reusable workflows.** `version-bump`, `issue-link`, `auto-merge` and `tag-on-merge` live in
  the private `adatoo/engineering-standards` repo, and a public repo can't call them.

The Mac mini's `ghrunner` runner also couldn't sign TestFlight builds (codesign failed with
errSecInternalComponent in the runner's session, #3), while Silicon Wallet signs the same way on
GitHub's hosted macOS without trouble.

## Decision

- **GitHub-hosted runners only.** They're free for public repos. Every workflow reads
  `vars.LINUX_RUNNER || 'ubuntu-latest'` and `vars.MAC_RUNNER || 'macos-26'`; the repo has neither
  variable and no self-hosted runner registered, so a fork has nothing to target.
- **Vendor the four shared workflows** into `.github/workflows/`, unchanged apart from a header
  comment naming the source version (v0.6.1), and call them as `./.github/workflows/<name>.yml`.
  To update one, copy the new version over it. This departs from the standards' "reuse, don't
  copy" rule, which assumes private repos.
- Fork pull requests need approval before their workflows run (Settings ▸ Actions).
- `testflight.yml` runs only on version tags and manual dispatch, never on a pull request.
- `merge.yml` uses `pull_request_target`, which runs the base branch's workflow with secrets. It's
  safe because the auto-merge job never checks out PR code and only acts on the owner's PRs.

## Consequences

- Hosted macOS runners are slower than the Mac mini and may lag behind new Xcode releases. If a
  build needs a newer Xcode than the image's default, select it with `DEVELOPER_DIR`.
- Hosted images don't have xcbeautify, so CI logs are xcodebuild's own.
