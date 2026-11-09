/// The script Easel adds to every rawumberstudios.com page.
///
/// It tells the app which video page is showing (from the page's own Next.js data) and,
/// once the site's JW Player has set up, the stream URL that player is using. Easel only
/// ever plays what the page's player was given for her account. Everything that depends
/// on how the site is built lives here, so if the site changes, look here first.
///
/// Messages to `window.webkit.messageHandlers.easel`:
///   { type: "page", video: { id, slug, title, tutor, thumbnail, description, dateLive,
///                            duration, isSeries, inTheFuture } | null }
///   { type: "stream", slug, url }
///   { type: "play", slug }      (play pressed in the site's player; Easel plays it instead)
enum EaselBridge {
    static let source = #"""
    (function () {
      if (window.__easelBridge) { return; }
      window.__easelBridge = true;

      function post(message) {
        try { window.webkit.messageHandlers.easel.postMessage(message); } catch (e) {}
      }

      function slugFromPath(path) {
        var match = path.match(/^\/n\/videos\/([^\/?#]+)/);
        return match ? decodeURIComponent(match[1]) : null;
      }

      // The same JSON the site fetches when it moves between pages.
      async function pageData(slug) {
        var next = window.__NEXT_DATA__;
        var build = next && next.buildId;
        if (!build) { return null; }
        try {
          var response = await fetch('/n/_next/data/' + build + '/videos/' + encodeURIComponent(slug) + '.json',
                                     { credentials: 'include' });
          if (!response.ok) { return null; }
          var json = await response.json();
          return (json && json.pageProps && json.pageProps.data && json.pageProps.data.video) || null;
        } catch (e) {
          return null;
        }
      }

      function streamFromPlayer(expectedId) {
        try {
          if (typeof window.jwplayer !== 'function') { return null; }
          var player = window.jwplayer();
          if (!player || typeof player.getPlaylistItem !== 'function') { return null; }
          var container = typeof player.getContainer === 'function' ? player.getContainer() : null;
          if (container && !document.body.contains(container)) { return null; }
          var item = player.getPlaylistItem();
          if (!item) { return null; }
          var file = item.file || (item.sources && item.sources[0] && item.sources[0].file);
          if (!file) { return null; }
          var url = new URL(file, location.href).href;
          // A player left over from the previous page would stream another video's ID.
          var id = url.match(/vod\.rawumberstudios\.com\/(\d+)\//);
          if (expectedId && id && Number(id[1]) !== expectedId) { return null; }
          return url;
        } catch (e) {
          return null;
        }
      }

      function summary(slug, video) {
        if (!video) {
          return { id: 0, slug: slug, title: document.title, tutor: '', thumbnail: '', description: '',
                   dateLive: null, duration: 0, isSeries: false, inTheFuture: false };
        }
        return {
          id: video.id || 0,
          slug: video.slug || slug,
          title: video.title || document.title,
          tutor: (video.tutor && video.tutor.name) || '',
          thumbnail: video.thumbnail || '',
          description: video.description || '',
          dateLive: video.dateLive || null,
          duration: video.duration || 0,
          isSeries: !!video.isSeries,
          inTheFuture: !!video.inTheFuture
        };
      }

      // Once Easel can play this page, any video starting to play on it hands over to Easel's
      // player instead. Media 'play' events don't bubble, so listen in the capture phase on the
      // document: that catches the site's player however and whenever it (re)builds itself.
      var playable = null;      // { slug, path } once the stream is known
      var pendingPlay = null;   // the path where play was pressed before the stream was known

      function handOver(slug) {
        window.__easelPause();
        post({ type: 'play', slug: slug });
      }

      document.addEventListener('play', function (event) {
        if (!(event.target instanceof HTMLMediaElement)) { return; }
        if (playable && playable.path === location.pathname) {
          handOver(playable.slug);
        } else {
          pendingPlay = location.pathname;
        }
      }, true);

      function streamReady(slug, path) {
        playable = { slug: slug, path: path };
        if (pendingPlay === path) {
          pendingPlay = null;
          handOver(slug);
        }
      }

      var currentPath = null;
      var poll = null;

      function stopPolling() {
        if (poll) { clearInterval(poll); poll = null; }
      }

      async function pageChanged() {
        var path = location.pathname;
        if (path === currentPath) { return; }
        currentPath = path;
        stopPolling();
        playable = null;

        var slug = slugFromPath(path);
        if (!slug) { post({ type: 'page', video: null }); return; }

        var info = summary(slug, await pageData(slug));
        if (location.pathname !== path) { return; }
        post({ type: 'page', video: info });
        if (info.isSeries) { return; }

        // The player sets itself up a moment after the page; look for its stream for ~20 s.
        var tries = 0;
        poll = setInterval(function () {
          tries += 1;
          if (location.pathname !== path || tries > 80) { stopPolling(); return; }
          var url = streamFromPlayer(info.id);
          if (url) {
            stopPolling();
            post({ type: 'stream', slug: info.slug, url: url });
            streamReady(info.slug, path);
          }
        }, 250);
      }

      // The site is a Next.js app: moving between pages changes the URL without a reload.
      function schedule() { setTimeout(pageChanged, 80); }
      ['pushState', 'replaceState'].forEach(function (name) {
        var original = history[name];
        history[name] = function () {
          var result = original.apply(this, arguments);
          schedule();
          return result;
        };
      });
      window.addEventListener('popstate', schedule);

      // Called by Easel before its own player starts, so the two don't play at once.
      window.__easelPause = function () {
        try { if (typeof window.jwplayer === 'function') { window.jwplayer().pause(); } } catch (e) {}
        document.querySelectorAll('video').forEach(function (video) {
          try { video.pause(); } catch (e) {}
        });
      };

      schedule();
    })();
    """#
}
