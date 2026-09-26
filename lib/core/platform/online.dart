import 'package:cgpa_calculator/core/platform/online_stub.dart'
    if (dart.library.js_interop) 'package:cgpa_calculator/core/platform/online_web.dart'
    as impl;

/// Whether the browser reports a connection, and changes to it.
bool get isOnline => impl.isOnline;
Stream<bool> get onlineChanges => impl.onlineChanges;
