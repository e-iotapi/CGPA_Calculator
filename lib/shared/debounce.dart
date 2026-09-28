import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs the last call only once calls pause for [delay] (UI_OPT O5.2): a
/// search field updates at once, and its result list after the typing stops.
/// Dispose it with the state that owns it.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 150)});

  final Duration delay;
  Timer? _timer;

  void call(VoidCallback f) {
    _timer?.cancel();
    _timer = Timer(delay, f);
  }

  void dispose() => _timer?.cancel();
}
