/// The live socket (LOADING_SERVER_PLAN.md D3): the server tells the app which
/// shared markers moved and when its own account changed elsewhere, so the
/// next load refetches only what changed. Only paths and counters travel;
/// no grades or user data. Off when [liveUrl] is empty; `headFor` keeps
/// working through the Worker or Firestore either way.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/live/live_channel.dart';
import 'package:cgpa_calculator/core/live/live_socket.dart';
import 'package:flutter/foundation.dart';

/// The live server's base URL; empty turns the socket off.
const liveUrl = String.fromEnvironment('POINTER_LIVE_URL');

const _maxFailures = 3;
const _maxFrame = 900; // the server drops frames of 1 KB or more

abstract final class LiveHeads {
  static final _moved = StreamController<Set<String>>.broadcast();

  /// Paths whose marker moved, as they arrive (and are saved).
  static Stream<Set<String>> get moved => _moved.stream;

  static int _gen = 0; // bumped by stop(): a loop from an older run quits
  static bool _started = false, _gaveUp = false;
  static int _failures = 0;
  static int? _lastMe;
  static LiveChannel? _ch;
  static Timer? _meTimer;
  static bool _pulling = false, _again = false;

  /// True once three connects failed: the socket stays off for the session.
  static bool get gaveUp => _gaveUp;

  /// Opens the socket for [campus] and keeps it open, reconnecting after a
  /// real drop. [idToken] is asked for at every connect. The rest is for
  /// tests: [baseUrl], [connect], [onMe] (the pull to run when the account
  /// moved elsewhere), [retry] (the wait before connect number n) and
  /// [pokeDelay].
  static void start(
    String campus,
    Future<String?> Function() idToken, {
    String baseUrl = liveUrl,
    Future<LiveChannel> Function(String url, List<String> protocols) connect =
        connectLive,
    Future<void> Function()? onMe,
    Duration Function(int attempt)? retry,
    Duration pokeDelay = const Duration(seconds: 2),
  }) {
    if (baseUrl.isEmpty || _started) return;
    _started = true;
    _pokeDelay = pokeDelay;
    _onMe = onMe;
    final base =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final url = '${base.replaceFirst(RegExp('^http'), 'ws')}/live/$campus';
    unawaited(_run(_gen, campus, url, idToken, connect, retry ?? _backoff));
  }

  /// Tells the server [path]'s marker moved (call after the write commits).
  /// Dropped while the socket is down: the head heals on the next fetch.
  static void poke(String path) {
    if (path.length > _maxFrame) return;
    _send({'t': 'poke', 'path': path});
  }

  /// Tells the server this account changed, one frame about two seconds
  /// after the last call, so a burst of writes sends one.
  static void pokeMe() {
    if (!_started) return;
    _meTimer?.cancel();
    _meTimer = Timer(_pokeDelay, () => _send({'t': 'pokeMe'}));
  }

  /// Closes the socket and ends the loop; [start] can be called again.
  static void stop() {
    _gen++;
    _started = _gaveUp = _pulling = _again = false;
    _failures = 0;
    _lastMe = null;
    _meTimer?.cancel();
    _meTimer = null;
    _ch?.close();
    _ch = null;
  }

  static Duration _pokeDelay = const Duration(seconds: 2);
  static Future<void> Function()? _onMe;

  static void _send(Map<String, Object?> m) {
    try {
      _ch?.send(jsonEncode(m));
    } on Object catch (e) {
      debugPrint('live send: $e');
    }
  }

  /// 1-10 s of jitter, doubling per attempt, capped at 5 min.
  static Duration _backoff(int attempt) {
    final base = 1 + Random().nextDouble() * 9;
    return Duration(
      milliseconds: min(300000, (base * 1000 * pow(2, attempt)).round()),
    );
  }

  static Future<void> _run(
    int gen,
    String campus,
    String url,
    Future<String?> Function() idToken,
    Future<LiveChannel> Function(String, List<String>) connect,
    Duration Function(int) retry,
  ) async {
    var attempt = 0;
    while (gen == _gen) {
      LiveChannel? ch;
      try {
        final tok = await idToken();
        if (tok == null || tok.isEmpty) throw StateError('no token');
        ch = await connect(url, ['pointer', tok]);
      } on Object {
        // counted below
      }
      var hello = false;
      if (ch != null) {
        if (gen != _gen) {
          ch.close();
          return;
        }
        _ch = ch;
        try {
          await for (final raw in ch.messages) {
            if (gen != _gen) break;
            hello = _onMessage(campus, raw) || hello;
          }
        } on Object {
          // a drop
        }
        if (_ch == ch) _ch = null;
      }
      if (gen != _gen) return;
      if (hello) {
        _failures = 0;
        attempt = 0;
      } else if (++_failures >= _maxFailures) {
        _gaveUp = true;
        return;
      }
      await Future<void>.delayed(retry(attempt++));
    }
  }

  /// Handles one frame; true when it was the hello (the connect worked).
  static bool _onMessage(String campus, String raw) {
    final Map m;
    try {
      m = jsonDecode(raw) as Map;
    } on Object {
      return false;
    }
    switch (m['t']) {
      case 'hello':
        _merge(campus, m['head']);
        _me(m['me'], pull: false);
        return true;
      case 'head':
        _merge(campus, m['v']);
      case 'me':
        _me(m['v'], pull: true);
    }
    return false;
  }

  /// Writes the new numbers into the saved `head|<campus>` (leaving its age
  /// and other fields alone) so the next load sees the moved marker and
  /// refetches. With no saved head there is nothing to correct: the next
  /// `headFor` reads a fresh one.
  static void _merge(String campus, Object? v) {
    if (v is! Map) return;
    final box = sharedCacheBox;
    final raw = box?.get('head|$campus');
    if (box == null || raw is! String) return;
    try {
      final entry = jsonDecode(raw) as Map;
      final head = Map<String, Object?>.from(entry['v'] as Map);
      final marks = Map<String, Object?>.from((head['v'] as Map?) ?? const {});
      final moved = <String>{};
      for (final e in v.entries) {
        final n = e.value;
        if (n is! num) continue;
        if (marks['${e.key}'] != n.toInt()) {
          marks['${e.key}'] = n.toInt();
          moved.add('${e.key}');
        }
      }
      if (moved.isEmpty) return;
      head['v'] = marks;
      entry['v'] = head;
      unawaited(
        box
            .put('head|$campus', jsonEncode(entry))
            .catchError((Object e) => debugPrint('live head: $e')),
      );
      _moved.add(moved);
    } on Object catch (e) {
      debugPrint('live merge: $e');
    }
  }

  static void _me(Object? v, {required bool pull}) {
    if (v is! num) return;
    final n = v.toInt(), last = _lastMe;
    if (last != null && n <= last) return;
    _lastMe = n;
    // The first number only sets the baseline: sign-in has just pulled.
    if (last != null || pull) unawaited(_pullMe());
  }

  static Future<void> _pullMe() async {
    final go = _onMe;
    if (go == null) return;
    if (_pulling) {
      _again = true;
      return;
    }
    _pulling = true;
    try {
      do {
        _again = false;
        await go();
      } while (_again);
    } on Object catch (e) {
      debugPrint('live pull: $e');
    } finally {
      _pulling = false;
    }
  }
}
