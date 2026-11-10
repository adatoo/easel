# Architecture

Easel is a single-target iPad app (iPadOS 17+, SwiftUI, SwiftData) that wraps
rawumberstudios.com. The site stays the source of truth: Easel asks it for everything, as her
signed-in browser would, and keeps only her own things (favourites, bookmarks, progress,
downloads) on the iPad. `AGENTS.md` lists where each part lives.

## How it works

- **SiteAPI** (`App/Site/SiteAPI.swift`): a web view parked out of sight on a site page runs the
  same JSON requests the site's own pages make (`/n/_next/data/...` and `/x/videosearch`), so
  everything carries her sign-in exactly as the site does. The scripts are in
  `App/Site/SiteScripts.swift`. Search asks for 25 results at a time, as the site does
  ([ADR-0002](adr/0002-site-through-hidden-web-views.md)).
- **StreamResolver**: to play or download, a second hidden web view loads the video's (or its
  series') page and reports the stream the site's JW Player was given
  (`vod.rawumberstudios.com/<id>/master.m3u8`, HLS, no DRM). Easel never builds stream URLs itself.
- **Player**: `AVPlayer` with external playback on, so AirPlay sends the stream itself to the
  Apple TV. It belongs to `AppModel`, so playback survives moving around the app.
- **Downloads**: `AVAssetDownloadURLSession` (background) saves the HLS stream as a `.movpkg`;
  an index is kept in Application Support/downloads.json.
- **Storage**: SwiftData (`Video`, `Bookmark`). CloudKit-compatible models; sync is off.

## Build and release

- `project.yml` is the XcodeGen spec; the Xcode project is generated and not committed
  ([ADR-0001](adr/0001-xcodegen-and-version.md)). `VERSION` is the single version source.
- `Taskfile.yml` is the only command surface, locally and in CI.
- CI (`.github/workflows/ci.yml`) lints on hosted Linux and formats, builds and tests on hosted
  macOS, then the `CI Gate` passes or fails the PR ([ADR-0005](adr/0005-public-repo-ci.md)).
- Each merge is tagged from `VERSION`, and the tag uploads a build to TestFlight
  ([ADR-0003](adr/0003-testflight-from-ci.md)).
