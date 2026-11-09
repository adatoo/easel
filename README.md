# Easel

An iPad app that wraps the [Raw Umber Studios](https://rawumberstudios.com/n/playlists) video
site for easier watching on the Apple TV. It's for personal use and isn't distributed.

## What it does

| Tab | |
|---|---|
| **Library** | The site's videos as big cards, searchable (titles, tutors, materials). Tap a card to play. |
| **Favourites** | Videos she has hearted. |
| **Continue** | Videos she has started, with how far through and how many bookmarks. Tap **Remove…** (top right) to take videos off the list, one at a time or all at once. |
| **Downloads** | Videos saved on the iPad, which play without internet. Swipe left to remove one. |
| **Website** | The site itself, signed in. On any video page she can play, a big **Watch in Easel** button appears. |

The player has large controls: play/pause, back/forward 10 s and 30 s, a scrubber, speed
(0.5×–1.5×) and **Bookmark this moment**. Bookmarks show as ticks on the scrubber and in a
list; tap one to jump to it, or the pencil to add a note. Easel remembers where she stopped and
resumes from there, with a **Start over** button.

The **AirPlay** button (top right of the player) sends the video to the Apple TV. The iPad
then works as the remote, and the Siri Remote, lock screen and Control Centre controls work too.

**Download** (in the player, or the toolbar on a video page) saves the video to the iPad at
1080p, about 2.5 GB an hour. Downloads carry on in the background. A downloaded video plays
from the iPad wherever she opens it, including from Favourites and Continue.

## How it works

- **Website.** A `WKWebView` with the default persistent data store, so she signs in once.
  `App/Site/EaselBridge.swift` is a small script injected into every page. It reports which video
  page is showing and the stream URL that the page's own JW Player was given. That stream is a
  plain HLS stream (`vod.rawumberstudios.com/<id>/master.m3u8`, H.264, no DRM).
- **Player.** `AVPlayer` with external playback on, so AirPlay sends the stream itself to the
  Apple TV rather than mirroring the screen. The site's own player has AirPlay disabled.
- **Downloads.** `AVAssetDownloadURLSession` (background) saves the same HLS stream as a
  `.movpkg`; `App/Downloads/` keeps an index in Application Support/downloads.json.
- **Library.** The same search endpoint the site's search page calls (`/x/videosearch`),
  25 results at a time as she scrolls, sent with her cookies.
- **Storage.** SwiftData (`Video`, `Bookmark`). The models are CloudKit-compatible but sync is
  off for now: add the iCloud capability to turn it on.

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
- **Downloads** from the site (model packs, reference photos) aren't handled in the web view yet.
- **Subtitles.** Many videos have them, but the player doesn't offer a subtitle switch yet.
