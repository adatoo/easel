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
- `project.yml`: the XcodeGen spec.

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

- `task open`: generate the project and open it.
- `task build`: Simulator build, unsigned.
