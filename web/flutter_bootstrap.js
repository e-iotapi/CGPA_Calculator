{{flutter_js}}
{{flutter_build_config}}

// ?msr=1 renders straight into the on-screen canvas (CanvasKit's
// multi-surface rasterizer) instead of drawing offscreen and copying each
// frame with createImageBitmap, the top self-time item in Chrome traces
// (PERF-02). A/B switch only; the default is unchanged.
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
      new URLSearchParams(location.search).get('msr') === '1',
  },
});
