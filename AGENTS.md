# Easel: notes for coding agents

An iPad app (iPadOS 17+, SwiftUI, SwiftData) that wraps rawumberstudios.com for Arif's wife:
browse and search the videos, favourites, continue watching, and a big-control AVPlayer that
AirPlays to the Apple TV. Personal use only, never on the App Store. README.md explains the features.

## Layout

- `App/Site/`: everything that depends on the website.
  - `SiteScripts.swift`: the scripts injected into the two hidden web views. If the site changes, fix these first.
  - `SiteAPI.swift`: search, playlists, video/series pages, who is signed in.
  - `StreamResolver.swift`: finds a video's stream from the site's own player.
  - `SiteModels.swift`: `VideoInfo`, playlists, tutors, search filters.
- `App/Library/`: the SwiftData models and `VideoStore`.
- `App/Views/`: the shell (`RootView`), Home, Search, the video/series page, My Easel and lists, account and website sheets, shared components.
- `App/Player/`: `PlayerModel` (AVPlayer, AirPlay, remote commands) and the player overlay, remote layout and mini bar.
- `App/Downloads/`: background HLS downloads.
- `App/AppModel.swift`: navigation, what's playing, bookmarks, downloads.
- `App/Theme.swift`: colours and button styles.
- `Tests/EaselTests/`: unit tests (Swift Testing) for the pure helpers.
- `project.yml`: the XcodeGen spec (ADR-0001). `VERSION` is the single version source.
- `docs/architecture.md` and `docs/adr/`: how it fits together and why.

## Rules

- Only play a stream that the page's own player was given for her account. Never build stream
  URLs from video IDs, and never get round the site's sign-in or subscription.
- Use the site's search like its own page does: 25 results per request, as she asks for more.
  Don't crawl or bulk-download the catalogue.
- Keep the UI big and simple. The person using it struggles with small video controls.
- Swift 5 language mode with minimal concurrency checking for now. Raise to Swift 6 /
  `complete` (as in Arif's other apps) once it has settled on her iPad.
- SwiftData models stay CloudKit-compatible: defaults on every property, optional relationships,
  no `@Attribute(.unique)`.

## Commands

`Taskfile.yml` is the only command surface; `task` lists everything.

- `task setup`: install the git hooks (once per clone).
- `task dev`: generate the project and open it in Xcode.
- `task build`: Simulator build, unsigned.
- `task test`: unit tests on an iPad simulator.
- `task fmt` / `task fmt:check`: swift-format.
- `task lint`, `task secrets`: workflows, shell scripts, Taskfile; gitleaks.
- `task ci`: everything CI runs; run it before pushing.
- `task release`, `task testflight:*`: TestFlight by hand (ADR-0003).

## Releasing

Every PR bumps `VERSION` and adds its `CHANGELOG.md` section in the last commit,
`chore(release): bump version to X.Y.Z`. That section becomes the build's What to Test, so write
it for her. Merging tags `vX.Y.Z`, and the tag's `testflight` workflow uploads the build; the
Family group gets it automatically.
