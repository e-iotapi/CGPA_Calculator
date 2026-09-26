import 'dart:async';

import 'package:web/web.dart' as web;

bool get isOnline => web.window.navigator.onLine;

Stream<bool> get onlineChanges => StreamGroup.merge([
  web.EventStreamProviders.onlineEvent.forTarget(web.window).map((_) => true),
  web.EventStreamProviders.offlineEvent.forTarget(web.window).map((_) => false),
]);

abstract final class StreamGroup {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    final c = StreamController<T>.broadcast();
    for (final s in streams) {
      s.listen(c.add);
    }
    return c.stream;
  }
}
