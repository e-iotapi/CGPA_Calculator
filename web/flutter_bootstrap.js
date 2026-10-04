{{flutter_js}}
{{flutter_build_config}}

// CanvasKit renders straight into the on-screen canvas (its multi-surface
// rasterizer) instead of drawing offscreen and copying each frame with
// createImageBitmap, the top self-time item in Chrome traces. On a real GPU
// at 4x CPU it cut missed frames on settings 50->23%, reviews 32->19%,
// theme 29->19% (PERF-02). Safari already renders this way. ?msr=0 restores
// the offscreen rasterizer for comparison.
// TM-10: on iPhone about 1 cold load in 8 never finished downloading the
// engine (canvaskit.wasm, 2.2 MB): no error, no progress, the splash
// forever. On WebKit (every iOS browser, and Safari) the engine is
// downloaded here instead: a download that goes 15 s without a byte is
// abandoned and retried until one completes. A retry of the same URL got
// no bytes either (behind the dead request), so each retry asks for a new
// URL, uncached, at high priority. It is compiled once complete.
{
  const ua = navigator.userAgent;
  if (/AppleWebKit/.test(ua) && !/Chrome|Chromium|Android/.test(ua)) {
    // TM-10 diagnostics: one console line per engine stage, so an iPhone
    // load that stops can be placed (download, compile or instantiate).
    const say = (m) => console.warn(`[engine] ${m} @${Math.round(performance.now())}`);
    const compile0 = WebAssembly.compileStreaming.bind(WebAssembly);
    WebAssembly.compileStreaming = (src) => {
      say('compile waits for download');
      return Promise.resolve(src)
        .then((res) => (say('compile starts'), compile0(res)))
        .then(
          (m) => (say('compiled'), m),
          (e) => (say(`compile failed: ${e}`), Promise.reject(e)),
        );
    };
    const instantiate0 = WebAssembly.instantiate.bind(WebAssembly);
    WebAssembly.instantiate = (m, imports) => {
      say('instantiate starts');
      return instantiate0(m, imports).then(
        (r) => (say('instantiated'), r),
        (e) => (say(`instantiate failed: ${e}`), Promise.reject(e)),
      );
    };
    addEventListener('flutter-first-frame', () => say('first frame'));
    const fetch0 = window.fetch.bind(window);
    const stallMs = 15000;
    const once = async (url, init) => {
      const abort = new AbortController();
      let timer;
      const arm = () => {
        clearTimeout(timer);
        timer = setTimeout(() => abort.abort(), stallMs);
      };
      arm();
      try {
        const res = await fetch0(url, { ...init, signal: abort.signal });
        if (!res.ok || !res.body) return res;
        const reader = res.body.getReader();
        const parts = [];
        for (;;) {
          arm();
          const { done, value } = await reader.read();
          if (done) break;
          parts.push(value);
        }
        say(`downloaded ${url.split('/').pop()}`);
        return new Response(new Blob(parts), {
          headers: { 'Content-Type': 'application/wasm' },
        });
      } finally {
        clearTimeout(timer);
      }
    };
    window.fetch = (input, init) => {
      const url = typeof input === 'string' ? input : input.url;
      if (!/(canvaskit|skwasm[a-z_]*)\.wasm$/.test(url.split('?')[0])) {
        return fetch0(input, init);
      }
      return (async () => {
        for (let retry = 0; ; retry++) {
          try {
            return retry === 0
              ? await once(url)
              : await once(`${url}${url.includes('?') ? '&' : '?'}retry=${retry}`, {
                  cache: 'no-store',
                  priority: 'high',
                });
          } catch (e) {
            console.warn(`Engine download stalled; retry ${retry + 1}`);
          }
        }
      })();
    };
  }
}

// No service worker settings: Flutter's service worker is now a stub that
// unregisters itself and reloads the page, and the loader awaits it (up to
// 4 s) before fetching anything. Browsers still update old registrations
// to that stub on their own, which cleans up the old app's worker.
_flutter.loader.load({
  config: {
    // Flutter keeps the WebAssembly build (skwasm) off for WebKit unless the
    // app opts in. It only matters for a --wasm build (the staging-wasm
    // preview, TM-14); a JS-only build has no wasm candidate to pick.
    wasmAllowList: { webkit: true },
    // CanvasKit from this site, not www.gstatic.com: the same brotli bytes
    // over the connection already open, without a DNS and TLS handshake to
    // a second host on the cold load's critical path (TM-10).
    canvasKitBaseUrl: 'canvaskit/',
    canvasKitForceMultiSurfaceRasterizer:
      new URLSearchParams(location.search).get('msr') !== '0',
  },
});
