# ADR-0002: Use the site through hidden web views, playing only its own streams

**Status:** Accepted
**Date:** 2026-11-10
**Deciders:** project owner

## Context

Raw Umber Studios has no public API. Its pages fetch JSON from its own endpoints with the
visitor's sign-in, and its JW Player is handed an HLS stream for the videos that account may
watch. Easel is for one subscriber's personal use and must not get round the site's sign-in or
subscription, nor load the site more heavily than she would in a browser.

## Decision

- Two web views, kept out of sight, do all the talking to the site:
  - **SiteAPI** stays on a site page and runs the same requests the site's pages make, through
    the scripts in `App/Site/SiteScripts.swift`, so every request carries her session.
  - **StreamResolver** loads a video's (or series') page and reports the stream the site's own
    player was given.
- Easel plays or downloads only a stream that the page's player was given for her account. It
  never builds stream URLs from video IDs.
- Search asks for 25 results per request, as the site's search page does, and more only as she
  scrolls. Easel never crawls or bulk-downloads the catalogue.
- Signing in happens on the site itself, in a sheet.

## Consequences

- When the site changes, `SiteScripts.swift` is the first place to fix.
- Sign in with Google doesn't work inside an embedded web view; email sign-in does.
- Subscriber streams over AirPlay may be refused if the Apple TV's own fetch needs cookies
  (README, Known gaps).
