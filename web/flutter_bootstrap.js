{{flutter_js}}
{{flutter_build_config}}

// CanvasKit renders straight into the on-screen canvas (its multi-surface
// rasterizer) instead of drawing offscreen and copying each frame with
// createImageBitmap, the top self-time item in Chrome traces. On a real GPU
// at 4x CPU it cut missed frames on settings 50->23%, reviews 32->19%,
// theme 29->19% (PERF-02). Safari already renders this way. ?msr=0 restores
// the offscreen rasterizer for comparison.
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
