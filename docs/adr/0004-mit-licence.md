# ADR-0004: Open source under the MIT licence

**Status:** Accepted
**Date:** 2026-11-10
**Deciders:** project owner

## Context

The engineering standards make personal repos proprietary by default. The owner wants Easel to
be open source, as Silicon Wallet is, so others with a Raw Umber Studios subscription can build
it for themselves and see how it works.

## Decision

- Easel is MIT-licensed, © 2026 Arif Datoo. Dependencies must be MIT/BSD/ISC-compatible.
- The repository is public. Easel is still not distributed through the App Store; anyone who
  wants it builds it with their own Apple developer team and bundle ID.
- Easel is unaffiliated with Raw Umber Studios. It needs the user's own sign-in and
  subscription, and keeps to ADR-0002: it plays only what the site's own player is given.

## Consequences

- Anyone can build, change and redistribute it.
- Closed or copyleft code can't be bundled.
- The repo's CI must be safe for a public repo (ADR-0005).
