/// The Worker's `GET /heads/<campus>`: a hint for `headFor`; Firestore stays
/// the source of truth (LOADING_SERVER_PLAN.md).
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/heads/heads_client_stub.dart'
    if (dart.library.js_interop) 'package:cgpa_calculator/core/heads/heads_client_web.dart'
    as impl;

/// The Worker's base URL; empty turns the Worker off.
const headsUrl = String.fromEnvironment('POINTER_HEADS_URL');

/// How long the Worker gets before the app falls back to Firestore.
const workerTimeout = Duration(seconds: 3);

/// [campus]'s head document from the Worker, or `null` on a non-200, a bad
/// body, a timeout or any error. [fetch] and [url] are for tests.
Future<Map<String, dynamic>?> workerHead(
  String campus, {
  String url = headsUrl,
  Future<({int status, String body})> Function(String url) fetch = impl.httpGet,
}) async {
  if (url.isEmpty) return null;
  try {
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final r = await fetch('$base/heads/$campus').timeout(workerTimeout);
    if (r.status != 200) return null;
    return (jsonDecode(r.body) as Map).cast<String, dynamic>();
  } on Object {
    return null;
  }
}
