# Architecture Decision Records

ADRs capture **why** a significant choice was made — the context, the decision, and its
consequences — so the reasoning survives after the code changes. They live in
`docs/adr/NNNN-title.md`, indexed here. Numbers are never reused.

An ADR describes the decision **as it stands**. When the decision changes, edit the ADR in place:
rewrite whatever is no longer true and update its **Date** and **Status**. Don't add amendment
sections or a superseding ADR; git history records what it used to say. If a decision is dropped
entirely, set its status to **Withdrawn** with a line on why.

Changing a decision needs the owner's explicit instruction. Updating an ADR to match a decision
that has already been made does not.

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](./0001-xcodegen-and-version.md) | XcodeGen project, with `VERSION` as the version source | Accepted |
| [0002](./0002-site-through-hidden-web-views.md) | Use the site through hidden web views, playing only its own streams | Accepted |
| [0003](./0003-testflight-from-ci.md) | TestFlight builds from CI | Accepted |
| [0004](./0004-mit-licence.md) | Open source under the MIT licence | Accepted |
| [0005](./0005-public-repo-ci.md) | GitHub-hosted runners only; shared workflows are vendored | Accepted |
