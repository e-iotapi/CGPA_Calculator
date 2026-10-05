/// Why sign-in fails, from the people it fails for: every failed attempt,
/// and the success that follows failures, go to Firestore (`signInLog`,
/// owner-read) and to the site's /api/signin-log (Cloudflare's real-time
/// logs). No address is ever sent.
library;

import 'dart:async';
import 'dart:convert';

import 'package:cgpa_calculator/core/platform/browser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

int _attempt = 0, _failed = 0;
final _clock = Stopwatch();

/// The Sign in button was tapped.
void signInStarted() {
  _attempt++;
  _clock
    ..reset()
    ..start();
}

/// The attempt failed at [stage] with [e].
void signInFailed(String stage, Object e) {
  _failed++;
  _send(signInEntry('failed', stage, e, attempt: _attempt, ms: _ms()));
}

/// The attempt worked; logged only after failures, to say what fixed it.
void signInSucceeded() {
  if (_failed > 0) {
    _send(signInEntry('ok', 'done', null, attempt: _attempt, ms: _ms()));
  }
}

int _ms() => _clock.elapsedMilliseconds;

final _email = RegExp(r'\S+@\S+');

/// One log entry. A refusal's text names the account, so only its kind is
/// kept; any address in a message is blanked.
@visibleForTesting
Map<String, Object> signInEntry(
  String outcome,
  String stage,
  Object? e, {
  required int attempt,
  required int ms,
  String? ua,
}) {
  final ua0 = ua ?? userAgent();
  final t = parseInstallTarget(ua0);
  String cut(String s, int n) => s.length > n ? s.substring(0, n) : s;
  return {
    'outcome': outcome,
    'stage': stage,
    'code': cut(switch (e) {
      null => '',
      FirebaseException(:final code) => code,
      String() => 'refused',
      _ => e.runtimeType.toString(),
    }, 80),
    'message': cut(switch (e) {
      FirebaseException(:final message) => message ?? '',
      null || String() => '',
      _ => '$e',
    }, 300).replaceAll(_email, '<email>'),
    'attempt': attempt,
    'ms': ms,
    'ua': cut(ua0, 400),
    'device': t.device.name,
    'browser': t.browser.name,
    'standalone': isStandalone(),
    'path': cut(Uri.base.path, 40),
  };
}

void _send(Map<String, Object> entry) {
  if (!kIsWeb) return;
  sendBeacon('${Uri.base.origin}/api/signin-log', jsonEncode(entry));
  unawaited(
    FirebaseFirestore.instance
        .collection('signInLog')
        .add({...entry, 'at': FieldValue.serverTimestamp()})
        .then((_) {}, onError: (_) {}),
  );
}
