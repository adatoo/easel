# Easel

An iPad app that wraps the [Raw Umber Studios](https://rawumberstudios.com/n/playlists) video
site for easier watching on the Apple TV. It's for personal use and isn't distributed.

## What it does

Three tabs: **Home**, **Search** and **My Easel**. There is no website tab; the site is used
behind the scenes, and opened in a sheet only for signing in, live sessions and extras.

- **Home**: a big Resume for the video she's in the middle of, then rows for Continue watching,
  Live this week, New sessions, My favourites and Raw Umber's playlists.
- **Search**: before typing, ways in by subject, materials, tutor and playlist. Results can be
  narrowed with the site's own filters (subject, materials, tutor, kind) plus "Not watched".
- **A page for every video and series**: a big Play/Resume, the parts of a series with progress
  and download state, her bookmarks, the site's extras (materials lists, model packs), and similar
  videos. "Download all" for a series.
- **My Easel**: favourites, bookmarks, downloads and recently watched, each with a full list
  where things can be removed.
- **Player**: full-screen video on the iPad with big controls that fade after a few seconds;
  bookmarks as chips above the scrubber and ticks on it; speed; subtitles when the stream has
  them; resume with "Start over". **Play on TV** opens the AirPlay picker; once the video is on the
  TV the iPad becomes a remote with very large buttons. Closing the player shrinks it to a bar
  above the tabs, and on the TV the video carries on while she browses.
- **Account** (the person button): signed in or not, download quality (1080p or 720p), sign out,
  and the Raw Umber website.

## How it works

See [docs/architecture.md](docs/architecture.md), and [docs/adr/](docs/adr/README.md) for the
decisions behind it.

## Building

Needs Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), [Task](https://taskfile.dev)
and, for the hooks and lint, lefthook, swift-format (with Xcode), actionlint, shellcheck and
gitleaks.

```sh
task setup   # once per clone: install the git hooks
task dev     # generate Easel.xcodeproj from project.yml and open it
task build   # build for the iOS Simulator (unsigned)
task test    # run the unit tests on an iPad simulator
task ci      # everything CI runs; run it before pushing
```

To put a development build on her iPad, connect it once by cable, turn on **Settings ▸ Privacy &
Security ▸ Developer Mode**, then choose the iPad in Xcode and Run.

## Releasing to TestFlight

Every merge to `main` is tagged `vX.Y.Z` from `VERSION`, and the tag's `testflight` workflow
archives and uploads that build on the Mac mini ([ADR-0003](docs/adr/0003-testflight-from-ci.md)).
Its What to Test comes from the version's `CHANGELOG.md` section. The internal **Family**
TestFlight group gets every build, so she only has to update in the TestFlight app.

By hand, with the App Store Connect API key in `.env.local` (never committed): `ASC_KEY_PATH`,
`ASC_KEY_ID`, `ASC_ISSUER_ID`.

```sh
task release                      # archive and upload a build (build number = commit count)
task testflight:status            # is it processed yet?
task testflight:invite EMAIL=… FIRST=… LAST=…   # add someone to the team (Customer Support, Easel only)
task testflight:setup EMAIL=…     # once they've accepted: add them to the "Family" TestFlight group
```

TestFlight builds expire after 90 days, so if nothing has merged for a couple of months, re-run
the latest `testflight` workflow (Actions ▸ testflight ▸ Run workflow).

## Known gaps

- **Subscriber streams over AirPlay.** Only the free video has been tested. If subscriber streams
  need her sign-in cookies, they play on the iPad (Easel passes the cookies to `AVPlayer`) but
  the Apple TV fetches AirPlay streams itself and may be refused. Test this with her account first.
- **Sign in with Google** doesn't work inside an embedded web view; email sign-in does.
- **Live sessions** open on the Raw Umber website; Easel doesn't play them itself.
