# ADR-0001: XcodeGen project, with `VERSION` as the version source

**Status:** Accepted
**Date:** 2026-11-10
**Deciders:** project owner

## Context

Xcode projects are large generated files that conflict in every branch that touches a target or
setting. The engineering standards also want a single version source that the release commit
changes alongside `CHANGELOG.md`, and that the tagging workflow can read without Xcode.

## Decision

- `project.yml` is the [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec; `task generate`
  writes `Easel.xcodeproj` and `Config/Info.plist`, and neither is committed.
- `VERSION` holds the app's version, `X.Y.Z`. `task generate` passes it to XcodeGen as
  `MARKETING_VERSION`, so the app's `CFBundleShortVersionString` always matches it.
- The build number (`CURRENT_PROJECT_VERSION`) is set when archiving: the commit count, so it
  always goes up (ADR-0003). Debug builds keep `1`.

## Consequences

- Every change to the project is a readable change to `project.yml`.
- Opening the project in Xcode needs `task dev` (or `task generate`) first.
- `version-bump.yml` and `tag-on-merge.yml` read `VERSION` directly.
