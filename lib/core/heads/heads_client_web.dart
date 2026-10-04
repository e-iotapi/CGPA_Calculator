import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<({int status, String body})> httpGet(String url) async {
  final r = await web.window.fetch(url.toJS).toDart;
  return (status: r.status, body: (await r.text().toDart).toDart);
}
