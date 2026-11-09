/// The script Easel adds to every rawumberstudios.com page.
///
/// It tells the app which video page is showing (from the page's own Next.js data), and finds
/// every one of the site's JW Players on the page: a video page has one, a series page has the
/// trailer plus each episode she can watch. Each player is covered with a "Watch in Easel"
/// button that plays that player's own stream in Easel. Easel only ever plays what the site's
/// players were given for her account. Everything that depends on how the site is built lives
/// here, so if the site changes, look here first.
///
/// Messages to `window.webkit.messageHandlers.easel`:
///   { type: "page", video: VideoSummary | null }   the page showing now
///   { type: "stream", slug, url }                  the page's own video can be played
///   { type: "playVideo", video: VideoSummary, url } play this in Easel (a cover was tapped,
///                                                  or one of the site's players started)
///   { type: "log", message }                       printed in debug builds
///
/// VideoSummary: { id, slug, title, tutor, thumbnail, description, dateLive, duration,
///                 isSeries, inTheFuture }
enum EaselBridge {
    static let source = #"""
    (function () {
      if (window.__easelBridge) { return; }
      window.__easelBridge = true;

      function post(message) {
        try { window.webkit.messageHandlers.easel.postMessage(message); } catch (e) {}
      }

      // Shown in Xcode's console in debug builds.
      function log(text) { post({ type: 'log', message: text + ' (' + location.pathname + ')' }); }

      function slugFromPath(path) {
        var match = path.match(/^\/n\/videos\/([^\/?#]+)/);
        return match ? decodeURIComponent(match[1]) : null;
      }

      function summary(video, fallbackSlug) {
        return {
          id: video.id || 0,
          slug: video.slug || fallbackSlug,
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

      // The same JSON the site fetches when it moves to this page.
      async function pageData(path) {
        var next = window.__NEXT_DATA__;
        var build = next && next.buildId;
        if (!build) { return null; }
        var route = path.replace(/^\/n/, '').replace(/\/$/, '') || '/index';
        try {
          var response = await fetch('/n/_next/data/' + build + route + '.json', { credentials: 'include' });
          if (!response.ok) { return null; }
          var json = await response.json();
          return (json && json.pageProps && json.pageProps.data) || null;
        } catch (e) {
          return null;
        }
      }

      // Every video the page's data describes (the page's own, a series' trailer and episodes,
      // related videos...), by ID.
      function collectVideos(data) {
        var found = {};
        (function walk(value, depth) {
          if (!value || typeof value !== 'object' || depth > 8) { return; }
          if (Array.isArray(value)) { value.forEach(function (item) { walk(item, depth + 1); }); return; }
          if (typeof value.id === 'number' && typeof value.slug === 'string' && typeof value.title === 'string') {
            if (!found[value.id]) { found[value.id] = summary(value, value.slug); }
          }
          Object.keys(value).forEach(function (key) { walk(value[key], depth + 1); });
        })(data, 0);
        return found;
      }

      // The site's players on the page: [{ container, url, id }].
      function sitePlayers() {
        if (typeof window.jwplayer !== 'function') { return []; }
        var players = [];
        document.querySelectorAll('.jwplayer').forEach(function (container) {
          try {
            var player = window.jwplayer(container.id || container);
            if (!player || typeof player.getPlaylistItem !== 'function') { return; }
            var item = player.getPlaylistItem();
            var file = item && (item.file || (item.sources && item.sources[0] && item.sources[0].file));
            if (!file) { return; }
            var url = new URL(file, location.href).href;
            var match = url.match(/vod\.rawumberstudios\.com\/(\d+)\//);
            players.push({ container: container, url: url, id: match ? Number(match[1]) : 0 });
          } catch (e) {}
        });
        return players;
      }

      // State for the page showing now.
      var currentPath = null;
      var pageVideo = null;     // the page's own video (summary), if it's a video page
      var videosByID = {};      // from the page's data
      var streamPosted = false;
      var scanTimer = null;
      var pendingContainer = null;  // a player that started before Easel could identify it

      function handOver(video, url) {
        window.__easelPause();
        log('hand over ' + video.slug);
        post({ type: 'playVideo', video: video, url: url });
      }

      function coverPlayer(container, video, url) {
        if (container.querySelector(':scope > .easel-cover')) { return; }
        if (getComputedStyle(container).position === 'static') { container.style.position = 'relative'; }
        var cover = document.createElement('div');
        cover.className = 'easel-cover';
        cover.setAttribute('style',
          'position:absolute;inset:0;z-index:2147483000;display:flex;align-items:center;' +
          'justify-content:center;background:rgba(0,0,0,0.35);cursor:pointer;' +
          '-webkit-tap-highlight-color:transparent;');
        // A smaller button on the small episode players of a series page.
        var small = container.getBoundingClientRect().width < 480;
        cover.innerHTML =
          '<div style="display:flex;align-items:center;border-radius:999px;background:#A0522D;color:#fff;' +
          'box-shadow:0 8px 24px rgba(0,0,0,.3);font-family:-apple-system,system-ui,sans-serif;font-weight:600;' +
          (small ? 'gap:10px;padding:12px 22px;font-size:18px">' : 'gap:14px;padding:20px 38px;font-size:26px">') +
          '<svg width="' + (small ? 18 : 26) + '" height="' + (small ? 20 : 28) + '" viewBox="0 0 26 28">' +
          '<path d="M2 1.5v25L25 14z" fill="#fff"/></svg>' +
          'Watch in Easel</div>';
        ['pointerdown', 'pointerup', 'mousedown', 'mouseup', 'touchstart', 'touchend'].forEach(function (type) {
          cover.addEventListener(type, function (event) { event.stopPropagation(); }, true);
        });
        cover.addEventListener('click', function (event) {
          event.preventDefault();
          event.stopPropagation();
          handOver(video, url);
        }, true);
        container.appendChild(cover);
        log('covered ' + video.slug);
      }

      // Runs every half second while the page is showing: players can appear at any time
      // (after login loads, when a series page builds its episode players, when the site
      // rebuilds a player).
      function scan() {
        sitePlayers().forEach(function (player) {
          var video = videosByID[player.id];
          if (!video) { return; }
          coverPlayer(player.container, video, player.url);
          if (pageVideo && !streamPosted && player.id === pageVideo.id) {
            streamPosted = true;
            post({ type: 'stream', slug: pageVideo.slug, url: player.url });
          }
          if (pendingContainer === player.container) {
            pendingContainer = null;
            handOver(video, player.url);
          }
        });
      }

      // Backstop: if one of the site's videos starts anyway, hand it to Easel.
      document.addEventListener('play', function (event) {
        if (!(event.target instanceof HTMLMediaElement)) { return; }
        var container = event.target.closest('.jwplayer');
        log('site video started');
        if (!container) { return; }
        var match = sitePlayers().filter(function (player) { return player.container === container; })[0];
        var video = match && videosByID[match.id];
        if (video) {
          handOver(video, match.url);
        } else {
          pendingContainer = container;
        }
      }, true);

      function stopScanning() {
        if (scanTimer) { clearInterval(scanTimer); scanTimer = null; }
        document.querySelectorAll('.easel-cover').forEach(function (cover) { cover.remove(); });
      }

      async function pageChanged() {
        var path = location.pathname;
        if (path === currentPath) { return; }
        currentPath = path;
        stopScanning();
        pageVideo = null;
        videosByID = {};
        streamPosted = false;
        pendingContainer = null;

        var data = await pageData(path);
        if (location.pathname !== path) { return; }
        videosByID = collectVideos(data);

        var slug = slugFromPath(path);
        if (slug) {
          var own = data && data.video;
          pageVideo = own ? summary(own, slug) : summary({ title: document.title }, slug);
          if (own && own.id) { videosByID[own.id] = pageVideo; }
        }
        post({ type: 'page', video: pageVideo });

        scan();
        scanTimer = setInterval(function () {
          if (location.pathname !== path) { stopScanning(); return; }
          scan();
        }, 500);
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
        try {
          document.querySelectorAll('.jwplayer').forEach(function (container) {
            var player = window.jwplayer(container.id || container);
            if (player && typeof player.pause === 'function') { player.pause(); }
          });
        } catch (e) {}
        document.querySelectorAll('video').forEach(function (video) {
          try { video.pause(); } catch (e) {}
        });
      };

      schedule();
    })();
    """#
}
