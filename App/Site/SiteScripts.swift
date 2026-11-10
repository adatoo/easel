/// The scripts Easel adds to its two background web views. Everything that depends on how
/// rawumberstudios.com is built lives here, so if the site changes, look here first.
enum SiteScripts {
    /// For the data web view, which stays parked on a site page. It fetches the same JSON the
    /// site's own pages fetch (so it sees exactly what her signed-in account sees) and returns a
    /// compact form of it. Every function returns a JSON string with a `status` (200 when fine).
    ///
    ///   bootstrap()      → { loggedIn, level, subscribed, tutors: [{id, name}], playlists: [{id, slug, name, about}] }
    ///   search(json)     → { count, videos: [Video] }      `json` is the site's own search request
    ///   playlist(slug)   → { name, videos: [Video] }
    ///   video(slug)      → { video, materials: [String], about, parts: [Video], trailer: Video|null,
    ///                        related: [Video], extras: [{title, url}] }
    ///
    /// Video: { id, slug, title, tutor, tutorId, thumbnail, description, dateLive, duration,
    ///          isSeries, inTheFuture, accessible, hasSubtitles }
    static let api = #"""
    (function () {
      if (window.__easelAPI) { return; }

      function compact(v) {
        return {
          id: v.id || 0,
          slug: v.slug || '',
          title: v.title || '',
          tutor: (v.tutor && v.tutor.name) || '',
          tutorId: v.tutorId || 0,
          thumbnail: v.thumbnail || '',
          description: v.description || '',
          dateLive: v.dateLive || null,
          duration: v.duration || 0,
          isSeries: !!v.isSeries,
          inTheFuture: !!v.inTheFuture,
          accessible: v.accessible !== false,
          hasSubtitles: !!v.hasSubtitles
        };
      }

      // The video's own materials: the list after "Materials used:" in its description.
      function materialsOf(v) {
        var items = [];
        var html = v.htmlDescription || '';
        if (html) {
          try {
            var doc = new DOMParser().parseFromString(html, 'text/html');
            var blocks = Array.prototype.slice.call(doc.body.children);
            for (var i = 0; i < blocks.length && !items.length; i++) {
              if (!/^materials( used)?\s*:?$/i.test((blocks[i].textContent || '').trim())) { continue; }
              for (var j = i + 1; j < blocks.length; j++) {
                var tag = blocks[j].tagName;
                if (tag === 'UL' || tag === 'OL') {
                  items = Array.prototype.slice.call(blocks[j].querySelectorAll('li'))
                    .map(function (li) { return (li.textContent || '').replace(/\s+/g, ' ').trim(); })
                    .filter(Boolean);
                  break;
                }
                if ((blocks[j].textContent || '').trim()) { break; }
              }
            }
          } catch (e) {}
        }
        if (!items.length) {
          var match = (v.description || '').match(/materials(?: used)?\s*:\s*([\s\S]+)$/i);
          if (match) { items = splitMaterials(match[1]); }
        }
        return items.map(function (item) {
          item = item.replace(/^and\s+/i, '').replace(/[.;,]+$/, '').trim();
          return item.charAt(0).toUpperCase() + item.slice(1);
        }).filter(function (item) { return item.length > 1; });
      }

      // "Willow charcoal. Soft pastels: a, b, c" → one item per sentence that has a colon,
      // otherwise one per comma ("black and white pencils" stays whole).
      function splitMaterials(text) {
        var out = [];
        text.replace(/\s+/g, ' ').trim().split(/\.\s+(?=[A-Z])/).forEach(function (sentence) {
          sentence = sentence.trim();
          if (!sentence) { return; }
          if (sentence.indexOf(':') >= 0) { out.push(sentence); return; }
          sentence.split(/\s*,\s*/).forEach(function (part) {
            if (part.trim()) { out.push(part.trim()); }
          });
        });
        return out;
      }

      // The description without its "Materials used" ending, which is shown as a list instead.
      function aboutOf(v) {
        return (v.description || '').replace(/\s*materials(?: used)?\s*:[\s\S]*$/i, '').trim();
      }

      function list(videos) {
        return (videos || []).filter(function (v) { return v && v.slug; }).map(compact);
      }

      async function getJSON(url) {
        try {
          var response = await fetch(url, { credentials: 'include' });
          if (!response.ok) { return { status: response.status }; }
          return { status: 200, json: await response.json() };
        } catch (e) {
          return { status: 0 };
        }
      }

      // The JSON the site fetches when it moves to a page. The build ID changes when the site is
      // redeployed; a 404 here tells Easel to reload this page and try again.
      async function pageJSON(route) {
        var next = window.__NEXT_DATA__;
        if (!next || !next.buildId) { return { status: 0 }; }
        return getJSON('/n/_next/data/' + next.buildId + route + '.json');
      }

      function pageData(json) {
        return (json && json.pageProps && json.pageProps.data) || {};
      }

      window.__easelAPI = {
        bootstrap: async function () {
          var r = await pageJSON('/playlists');
          if (r.status !== 200) { return JSON.stringify(r); }
          var json = r.json;
          var base = (window.__NEXT_DATA__ && window.__NEXT_DATA__.props) || {};
          var user = json.userInformation || base.userInformation || {};
          var loggedIn = ('loggedIn' in json) ? json.loggedIn : base.loggedIn;
          var playlists = (pageData(json).playlists || []).slice();
          playlists.sort(function (a, b) { return (a.sequence || 0) - (b.sequence || 0); });
          return JSON.stringify({
            status: 200,
            loggedIn: !!loggedIn,
            level: user.subscriber_level || 'none',
            subscribed: !!user.subscribed,
            tutors: (json.tutors || base.tutors || []).map(function (t) { return { id: t.id, name: t.name }; }),
            playlists: playlists.map(function (p) {
              return { id: p.id || 0, slug: p.slug || '', name: p.description || p.slug || '', about: p.longDescription || '' };
            })
          });
        },

        search: async function (json) {
          var r = await getJSON('/x/videosearch?json=' + encodeURIComponent(json));
          if (r.status !== 200) { return JSON.stringify(r); }
          return JSON.stringify({ status: 200, count: r.json.count || 0, videos: list(r.json.videos) });
        },

        playlist: async function (slug) {
          var r = await pageJSON('/playlists/' + encodeURIComponent(slug));
          if (r.status !== 200) { return JSON.stringify(r); }
          var data = pageData(r.json);
          return JSON.stringify({
            status: 200,
            name: (data.playlist && data.playlist.description) || '',
            videos: list(data.videos)
          });
        },

        video: async function (slug) {
          var r = await pageJSON('/videos/' + encodeURIComponent(slug));
          if (r.status !== 200) { return JSON.stringify(r); }
          var data = pageData(r.json);
          if (!data.video) { return JSON.stringify({ status: 404 }); }
          return JSON.stringify({
            status: 200,
            video: compact(data.video),
            materials: materialsOf(data.video),
            about: aboutOf(data.video),
            parts: list(data.videosInSeries),
            trailer: (data.trailer && data.trailer.slug) ? compact(data.trailer) : null,
            related: list(data.relatedVideos),
            extras: (data.ancillaryLinks || [])
              .filter(function (link) { return link && link.url && !link.notLive; })
              .map(function (link) { return { title: link.description || 'Link', url: link.url }; })
          });
        }
      };
    })();
    """#

    /// For the website sheet. Links to videos, and videos starting to play, open in Easel
    /// instead, except on the one video page the sheet was opened for (a live session, or a
    /// video outside her subscription). `window.__easelAllowedSlug` names that page.
    ///
    /// Messages to `window.webkit.messageHandlers.easelSheet`:
    ///   { type: "openVideo", slug, title }
    static let website = #"""
    (function () {
      if (window.__easelSheet) { return; }
      window.__easelSheet = true;

      function post(message) {
        try { window.webkit.messageHandlers.easelSheet.postMessage(message); } catch (e) {}
      }

      function slugOf(href) {
        try {
          var url = new URL(href, location.href);
          if (!/(^|\.)rawumberstudios\.com$/.test(url.hostname)) { return null; }
          var match = url.pathname.match(/^\/(?:n\/)?videos\/([^\/?#]+)\/?$/);
          return match ? decodeURIComponent(match[1]) : null;
        } catch (e) {
          return null;
        }
      }

      function allowed() { return window.__easelAllowedSlug || null; }

      // The site's own page links move between pages without loading, so catch the click
      // before the site's code sees it.
      document.addEventListener('click', function (event) {
        var link = event.target && event.target.closest ? event.target.closest('a[href]') : null;
        if (!link) { return; }
        var slug = slugOf(link.getAttribute('href'));
        if (!slug || slug === allowed() || slug === slugOf(location.href)) { return; }
        event.preventDefault();
        event.stopPropagation();
        event.stopImmediatePropagation();
        post({ type: 'openVideo', slug: slug, title: (link.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 140) });
      }, true);

      function slugForPlayer(id) {
        var found = null;
        (function walk(value, depth) {
          if (found || !value || typeof value !== 'object' || depth > 8) { return; }
          if (Array.isArray(value)) { value.forEach(function (item) { walk(item, depth + 1); }); return; }
          if (value.id === id && typeof value.slug === 'string') { found = value.slug; return; }
          Object.keys(value).forEach(function (key) { walk(value[key], depth + 1); });
        })(window.__NEXT_DATA__, 0);
        return found;
      }

      // A video starting to play anywhere else (the front page's featured video, say).
      document.addEventListener('play', function (event) {
        if (!(event.target instanceof HTMLMediaElement)) { return; }
        var slug = slugOf(location.href);
        if (slug && slug === allowed()) { return; }
        if (!slug) {
          try {
            var container = event.target.closest('.jwplayer');
            var match = container && container.id.match(/(\d+)$/);
            slug = match ? slugForPlayer(Number(match[1])) : null;
          } catch (e) {}
        }
        if (!slug) { return; }
        try { event.target.pause(); } catch (e) {}
        post({ type: 'openVideo', slug: slug, title: '' });
      }, true);
    })();
    """#

    /// For the stream web view, which loads a video's (or series') page out of sight. It reports
    /// the stream each of the site's JW Players on the page was given, so Easel only ever plays
    /// what the site set up for her account. A series page has a player for the trailer and for
    /// each part she can watch.
    ///
    /// Messages to `window.webkit.messageHandlers.easelStreams`:
    ///   { type: "stream", id, url }    `id` is the site's video ID
    static let streams = #"""
    (function () {
      if (window.__easelStreams) { return; }
      window.__easelStreams = true;

      function post(message) {
        try { window.webkit.messageHandlers.easelStreams.postMessage(message); } catch (e) {}
      }

      // The page's own video, for a stream URL that doesn't carry the ID.
      function pageVideoID() {
        try {
          var data = window.__NEXT_DATA__.props.pageProps.data;
          return (data && data.video && !data.video.isSeries && data.video.id) || 0;
        } catch (e) {
          return 0;
        }
      }

      var sent = {};

      function scan() {
        if (typeof window.jwplayer !== 'function') { return; }
        document.querySelectorAll('.jwplayer').forEach(function (container) {
          try {
            var player = window.jwplayer(container.id || container);
            if (!player || typeof player.getPlaylistItem !== 'function') { return; }
            var item = player.getPlaylistItem();
            var file = item && (item.file || (item.sources && item.sources[0] && item.sources[0].file));
            if (!file) { return; }
            var url = new URL(file, location.href).href;
            var match = url.match(/\/(\d+)\/master\.m3u8/);
            var id = match ? Number(match[1]) : pageVideoID();
            if (!id || sent[id] === url) { return; }
            sent[id] = url;
            post({ type: 'stream', id: id, url: url });
          } catch (e) {}
        });
      }

      // Nothing should ever play in this page.
      document.addEventListener('play', function (event) {
        try { event.target.pause(); } catch (e) {}
      }, true);

      scan();
      setInterval(scan, 400);
    })();
    """#
}
