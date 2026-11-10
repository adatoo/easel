# ADR-0003: TestFlight builds from CI

**Status:** Accepted
**Date:** 2026-11-10 (monthly refresh, 2026-11-10)
**Deciders:** project owner

## Context

Easel is for one person's iPad. Installing from Xcode needs the iPad at hand and a cable or
Developer Mode, and a development build expires within days or a year. TestFlight installs over
the air, keeps each build for 90 days, and needs no App Review for internal testers. The other
Apple apps (Silicon Wallet, DocuFile) already upload every release from CI.

## Decision

- **Every release goes to TestFlight.**
  - `tag.yml` tags each merge to `main` `vX.Y.Z` from `VERSION`, through the `adatoo-automation`
    App, so the tag can start other workflows.
  - The tag starts `.github/workflows/testflight.yml` on GitHub's hosted macOS (ADR-0005), which
    runs `task release`, then `task testflight:notes` to set What to Test from `CHANGELOG.md`.
  - It isn't part of the `CI Gate`, so a failed upload never blocks a merge. It can be re-run by
    hand (`workflow_dispatch`).
  - It also runs on the 1st of every month and uploads a fresh build of `main`, so the newest
    build is never close to TestFlight's 90-day expiry, merges or not. GitHub turns off a public
    repo's schedules after 60 days without activity, so each run enables its workflow again.
- **Signing, as in Silicon Wallet:** automatic, with `-allowProvisioningUpdates` and an App Store
  Connect API key with the **Admin** role.
  - Archiving on a fresh runner makes an "Apple Development: Created via API" certificate. The job
    revokes every such certificate when it ends, pass or fail (`task release:prune-certificates`),
    so they never reach Apple's limit. Certificates made in Xcode or on the website are untouched.
  - The export (`Config/ExportOptions.plist`, `app-store-connect`, `upload`) re-signs with Apple's
    cloud-managed distribution certificate, so no distribution key lives on the runner or in GitHub.
  - Easel has one target and no extensions, so the API key can make every profile it needs; no
    `.p12` or job keychain is needed (unlike DocuFile).
- **Secrets:** `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` (the `.p8` file's contents), the
  same team key Silicon Wallet uses. The job writes the `.p8` to the runner's temporary folder,
  readable only by the runner, and deletes it at the end even if the job fails.
- **Build number:** the commit count (`git rev-list --count HEAD`), so it always goes up. A
  scheduled or manual run may rebuild a commit already uploaded, so it uses
  `<commit count>.<run number>` (say `23.41`), which is new and later for the same version.
- **Testers:** an internal group, **Family**, that gets every build. Internal testers must be
  App Store Connect users, so each is invited with the Customer Support role and access to Easel
  only (`task testflight:invite`, then `task testflight:setup`).
- The app declares no non-exempt encryption (`ITSAppUsesNonExemptEncryption`), so builds need no
  export-compliance answer.

## Consequences

- Each merge reaches her iPad through the TestFlight app, with no Xcode or cable.
- Uploads don't depend on the Mac mini. The Mac mini's `ghrunner` runner couldn't sign (#3).
- Pruning is team-wide: a Silicon Wallet and an Easel upload running at the same moment could
  revoke each other's certificate mid-run. Re-run the one that failed.
- TestFlight builds expire after 90 days, and Apple allows no longer; the monthly run keeps a
  build of at most a month old in TestFlight.
- **Owner's one-time set-up** (not automated): the App Store Connect app record, the API key and
  its secrets, and testers accepting their invitations.
