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
// abandoned and retried, up to 3 more times. It is compiled once complete.
{
  const ua = navigator.userAgent;
  if (/AppleWebKit/.test(ua) && !/Chrome|Chromium|Android/.test(ua)) {
    const fetch0 = window.fetch.bind(window);
    const stallMs = 15000;
    const once = async (url) => {
      const abort = new AbortController();
      let timer;
      const arm = () => {
        clearTimeout(timer);
        timer = setTimeout(() => abort.abort(), stallMs);
      };
      arm();
      try {
        const res = await fetch0(url, { signal: abort.signal });
        if (!res.ok || !res.body) return res;
        const reader = res.body.getReader();
        const parts = [];
        for (;;) {
          arm();
          const { done, value } = await reader.read();
          if (done) break;
          parts.push(value);
        }
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
            return await once(url);
          } catch (e) {
            if (retry >= 3) throw e;
            console.warn(`Engine download stalled; retry ${retry + 1}`);
          }
        }
      })();
    };
  }
}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    // CanvasKit from this site, not www.gstatic.com: the same brotli bytes
    // over the connection already open, without a DNS and TLS handshake to
    // a second host on the cold load's critical path (TM-10).
    canvasKitBaseUrl: 'canvaskit/',
    canvasKitForceMultiSurfaceRasterizer:
      new URLSearchParams(location.search).get('msr') !== '0',
  },
});
