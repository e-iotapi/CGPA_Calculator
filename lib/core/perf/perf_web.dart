/// Publishes Perf's counters as `window.pointerPerf`, for the T6 perf and
/// quota specs (PERF_TEST_PLAN.md P0). Follows the pattern in
/// core/platform/browser_web.dart.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void publishPerf({
  required int Function(String name) reads,
  required int Function(String name) writes,
  required Map<String, int> Function() summary,
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
  globalContext.setProperty('pointerPerf'.toJS, obj);
}
