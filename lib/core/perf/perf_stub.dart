/// The non-web target of perf.dart's conditional import: nothing to publish
/// to, since there is no `window`.
void publishPerf({
  required int Function(String name) reads,
  required int Function(String name) writes,
  required Map<String, int> Function() summary,
}) {}
