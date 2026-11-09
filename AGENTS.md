# Easel: notes for coding agents

An iPad app (iPadOS 17+, SwiftUI, SwiftData) that wraps rawumberstudios.com for Arif's wife:
browse and search the videos, favourites, continue watching, and a big-control AVPlayer that
AirPlays to the Apple TV. Personal use only, never on the App Store. README.md explains the features.

## Layout

- `App/Site/`: everything that depends on the website.
  - `EaselBridge.swift`: the injected page script. If the site changes, fix this first.
  - `RawUmber.swift`: the site's URLs.
  - `Catalog.swift`: the site's search endpoint.
  - `WebController.swift`: the web view.
- `App/Library/`: `VideoInfo` (from the site), the SwiftData models, `VideoStore`.
- `App/Views/`: the four tabs and the video card.
- `App/Player/`: `PlayerModel` (AVPlayer, AirPlay, remote commands, Now Playing) and `PlayerScreen`.
- `project.yml`: the XcodeGen spec. Edit it rather than the generated project, which isn't committed.

## Rules

- Only play a stream that the page's own player was given for her account. Never build stream
  URLs from video IDs, and never get round the site's sign-in or subscription.
- Use the site's search like its own page does: 25 results per request, as she scrolls. Don't
  crawl or bulk-download the catalogue.
- Keep the UI big and simple. The person using it struggles with small video controls.
- Swift 5 language mode with minimal concurrency checking for now. Raise to Swift 6 /
  `complete` (as in Arif's other apps) once it has settled on her iPad.
- SwiftData models stay CloudKit-compatible: defaults on every property, optional relationships,
  no `@Attribute(.unique)`.

## Commands

- `task open`: generate the project and open it.
- `task build`: Simulator build, unsigned.
