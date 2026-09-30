/// Publishes Perf's counters as `window.pointerPerf`, for the T6 perf and
/// quota specs (PERF_TEST_PLAN.md P0). Follows the pattern in
/// core/platform/browser_web.dart.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Exposes the counter getters on `window.pointerPerf`.
void publishPerf({
  required int Function(String name) reads,
  required int Function(String name) writes,
  required Map<String, int> Function() summary,
  required Map<String, List<int>> Function() timings,
}) {
  final obj = JSObject();
  obj.setProperty(
    'reads'.toJS,
    ((JSString name) => reads(name.toDart)).toJS,
  );
  obj.setProperty(
    'writes'.toJS,
    ((JSString name) => writes(name.toDart)).toJS,
  );
  obj.setProperty(
    'summary'.toJS,
    (() {
      final s = summary();
      final o = JSObject();
      o.setProperty('reads'.toJS, (s['reads'] ?? 0).toJS);
      o.setProperty('writes'.toJS, (s['writes'] ?? 0).toJS);
      return o;
    }).toJS,
  );
  // Every timing recorded so far, as JSON: {"startup.syncInit": [812], …}.
  obj.setProperty('timings'.toJS, (() => jsonEncode(timings()).toJS).toJS);
  globalContext.setProperty('pointerPerf'.toJS, obj);
}
