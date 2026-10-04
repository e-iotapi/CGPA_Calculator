import 'dart:async';
import 'dart:js_interop';

import 'package:cgpa_calculator/core/live/live_channel.dart';
import 'package:web/web.dart' as web;

class _WebChannel implements LiveChannel {
  _WebChannel(this._ws, this.messages);
  final web.WebSocket _ws;
  @override
  final Stream<String> messages;

  @override
  void send(String frame) => _ws.send(frame.toJS);

  @override
  void close() => _ws.close();
}

Future<LiveChannel> connect(String url, List<String> protocols) {
  final open = Completer<LiveChannel>();
  final ws = web.WebSocket(url, [for (final p in protocols) p.toJS].toJS);
  final msgs = StreamController<String>();
  web.EventStreamProviders.openEvent.forTarget(ws).first.then((_) {
    if (!open.isCompleted) open.complete(_WebChannel(ws, msgs.stream));
  });
  web.EventStreamProviders.messageEvent.forTarget(ws).listen((e) {
    final d = e.data;
    if (d.isA<JSString>()) msgs.add((d as JSString).toDart);
  });
  void ended([Object? _]) {
    if (!open.isCompleted) open.completeError(StateError('socket closed'));
    if (!msgs.isClosed) msgs.close();
  }

  web.EventStreamProviders.errorEvent.forTarget(ws).listen(ended);
  web.EventStreamProviders.closeEvent.forTarget(ws).listen(ended);
  return open.future;
}
