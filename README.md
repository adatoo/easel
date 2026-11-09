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

- **SiteAPI** (`App/Site/SiteAPI.swift`): a web view parked out of sight on a site page runs the
  same JSON requests the site's own pages make (`/n/_next/data/...` and `/x/videosearch`), so
  everything carries her sign-in exactly as the site does. The scripts are in
  `App/Site/SiteScripts.swift`.
- **StreamResolver**: to play or download, a second hidden web view loads the video's (or its
  series') page and reports the stream the site's JW Player was given
  (`vod.rawumberstudios.com/<id>/master.m3u8`, HLS, no DRM). Easel never builds stream URLs itself.
- **Player**: `AVPlayer` with external playback on, so AirPlay sends the stream itself to the
  Apple TV. It belongs to `AppModel`, so playback survives moving around the app.
- **Downloads**: `AVAssetDownloadURLSession` (background) saves the HLS stream as a `.movpkg`;
  an index is kept in Application Support/downloads.json.
- **Storage**: SwiftData (`Video`, `Bookmark`). CloudKit-compatible models; sync is off.

## Building

Needs Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) and [Task](https://taskfile.dev).

```sh
task open    # generate Easel.xcodeproj from project.yml and open it
task build   # build for the iOS Simulator (unsigned)
```

To put it on her iPad, connect it once by cable, turn on **Settings ▸ Privacy & Security ▸
Developer Mode**, then choose the iPad in Xcode and Run. After the first time, Xcode can install
over Wi-Fi. A development-signed install lasts about a year. Later, move to TestFlight as an
internal tester to avoid needing the iPad at hand.

## Known gaps

- **Subscriber streams over AirPlay.** Only the free video has been tested. If subscriber streams
  need her sign-in cookies, they play on the iPad (Easel passes the cookies to `AVPlayer`) but
  the Apple TV fetches AirPlay streams itself and may be refused. Test this with her account first.
- **Sign in with Google** doesn't work inside an embedded web view; email sign-in does.
- **Live sessions** open on the Raw Umber website; Easel doesn't play them itself.
