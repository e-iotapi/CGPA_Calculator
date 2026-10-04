import 'package:cgpa_calculator/core/live/live_channel.dart';
import 'package:cgpa_calculator/core/live/live_socket_stub.dart'
    if (dart.library.js_interop) 'package:cgpa_calculator/core/live/live_socket_web.dart'
    as impl;

/// Opens a WebSocket to [url] offering [protocols]; completes once open,
/// throws when it cannot open. Always throws off the web.
Future<LiveChannel> connectLive(String url, List<String> protocols) =>
    impl.connect(url, protocols);
