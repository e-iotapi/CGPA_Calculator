// The live socket (LOADING_SERVER_PLAN D3): markers and the personal version
// arrive over one WebSocket; tests drive it with a fake channel.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/heads.dart';
import 'package:cgpa_calculator/core/live/live_channel.dart';
import 'package:cgpa_calculator/core/live/live_heads.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class FakeChannel implements LiveChannel {
  final in_ = StreamController<String>();
  final sent = <Map<String, dynamic>>[];
  bool closed = false;
  @override
  Stream<String> get messages => in_.stream;
  @override
  void send(String frame) =>
      sent.add(jsonDecode(frame) as Map<String, dynamic>);
  @override
  void close() {
    closed = true;
    if (!in_.isClosed) in_.close();
  }

  void push(Map<String, Object?> m) => in_.add(jsonEncode(m));
  void drop() => in_.close();
}

void main() {
  late Directory dir;
  late List<FakeChannel> chans;
  late List<(String, List<String>)> dials;
  var failConnect = 0; // fail this many connects first
  var pulls = 0;
  int? stored; // the persisted last `me`

  Future<LiveChannel> connect(String url, List<String> protocols) async {
    dials.add((url, protocols));
    if (failConnect > 0) {
      failConnect--;
      throw StateError('refused');
    }
    final c = FakeChannel();
    chans.add(c);
    return c;
  }

  void start({Future<String?> Function()? token}) => LiveHeads.start(
    'goa',
    token ?? () async => 'tok',
    baseUrl: 'https://live.example',
    connect: connect,
    onMe: () async => pulls++,
    loadMe: () => stored,
    saveMe: (n) => stored = n,
    retry: (_) => const Duration(milliseconds: 5),
    pokeDelay: const Duration(milliseconds: 40),
  );

  Map<String, dynamic> savedV() =>
      (jsonDecode(sharedCacheBox!.get('head|goa') as String) as Map)['v']['v']
          as Map<String, dynamic>;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_live');
    Hive.init(dir.path);
    await openSharedCache();
    // A head the app already holds: catalogue 3, resources at 4.
    await sharedCacheBox!.put(
      'head|goa',
      jsonEncode({
        'at': 123,
        'v': const Head(catalog: 3, v: {'resources': 4}).toMap(),
        'ver': null,
      }),
    );
    chans = [];
    dials = [];
    failConnect = 0;
    pulls = 0;
    stored = null;
  });
  tearDown(() async {
    LiveHeads.stop();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('off without a URL', () async {
    LiveHeads.start('goa', () async => 'tok', connect: connect);
    await pumpEventQueue();
    expect(dials, isEmpty);
  });

  test('dials /live/<campus> with the token as a subprotocol', () async {
    start();
    await pumpEventQueue();
    expect(dials.single.$1, 'wss://live.example/live/goa');
    expect(dials.single.$2, ['pointer', 'tok']);
  });

  test(
    'hello saves the head: moved paths reach the cache and the stream',
    () async {
      final moved = <Set<String>>[];
      final sub = LiveHeads.moved.listen(moved.add);
      start();
      await pumpEventQueue();
      chans.single.push({
        't': 'hello',
        'head': {'resources': 6, 'reps': 1},
        'me': 9,
      });
      await pumpEventQueue();
      expect(savedV(), {'resources': 6, 'reps': 1});
      expect(moved.single, {'resources', 'reps'});
      // The rest of the head and its age are untouched, so a load now sees the
      // new marker without the head being treated as fresh.
      final m = jsonDecode(sharedCacheBox!.get('head|goa') as String) as Map;
      expect(m['at'], 123);
      expect((m['v'] as Map)['catalog'], 3);
      await sub.cancel();
    },
  );

  test('head merges only what moved and emits it', () async {
    final moved = <Set<String>>[];
    final sub = LiveHeads.moved.listen(moved.add);
    start();
    await pumpEventQueue();
    final c = chans.single;
    c.push({
      't': 'hello',
      'head': {'resources': 4, 'reps': 1},
      'me': 1,
    });
    await pumpEventQueue();
    moved.clear();
    c.push({
      't': 'head',
      'v': {'resources': 5},
    });
    await pumpEventQueue();
    expect(savedV(), {'resources': 5, 'reps': 1});
    expect(moved.single, {'resources'});
    c.push({
      't': 'head',
      'v': {'resources': 5},
    }); // nothing new: no event
    await pumpEventQueue();
    expect(moved.length, 1);
    await sub.cancel();
  });

  test('poke sends only the path, as JSON', () async {
    start();
    await pumpEventQueue();
    LiveHeads.poke('reviews/CS F111');
    expect(chans.single.sent, [
      {'t': 'poke', 'path': 'reviews/CS F111'},
    ]);
  });

  test('a poke with nobody listening is dropped, not queued', () async {
    LiveHeads.poke('resources'); // not started
    start();
    await pumpEventQueue();
    expect(chans.single.sent, isEmpty);
  });

  test('pokeMe is debounced: one frame after the last call', () async {
    start();
    await pumpEventQueue();
    LiveHeads.pokeMe();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    LiveHeads.pokeMe();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(chans.single.sent, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(chans.single.sent, [
      {'t': 'pokeMe'},
    ]);
  });

  test(
    'me above the last seen pulls; the hello only sets the baseline',
    () async {
      start();
      await pumpEventQueue();
      final c = chans.single;
      c.push({'t': 'hello', 'head': <String, int>{}, 'me': 5});
      await pumpEventQueue();
      expect(pulls, 0);
      c.push({'t': 'me', 'v': 5}); // not greater
      await pumpEventQueue();
      expect(pulls, 0);
      c.push({'t': 'me', 'v': 6});
      await pumpEventQueue();
      expect(pulls, 1);
      c.push({'t': 'me', 'v': 4}); // stale, out of order
      await pumpEventQueue();
      expect(pulls, 1);
    },
  );

  test(
    'a cold launch pulls when hello me is above the saved one, then saves it',
    () async {
      stored = 5;
      start();
      await pumpEventQueue();
      chans.single.push({'t': 'hello', 'head': <String, int>{}, 'me': 7});
      await pumpEventQueue();
      expect(pulls, 1);
      expect(stored, 7);
    },
  );

  test(
    'our own pokeMe echo is saved without a pull; a bigger jump pulls',
    () async {
      stored = 5;
      start();
      await pumpEventQueue();
      final c = chans.single;
      c.push({'t': 'hello', 'head': <String, int>{}, 'me': 5});
      await pumpEventQueue();
      LiveHeads.pokeMe();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      c.push({'t': 'me', 'v': 6}); // our own write, echoed
      await pumpEventQueue();
      expect(pulls, 0);
      expect(stored, 6);
      LiveHeads.pokeMe();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      c.push({'t': 'me', 'v': 8}); // ours and another device's
      await pumpEventQueue();
      expect(pulls, 1);
      expect(stored, 8);
    },
  );

  test('three failed connects stop it for the session', () async {
    failConnect = 99;
    start();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(dials.length, 3);
    LiveHeads.poke('resources'); // harmless
  });

  test('a missing token counts as a failed connect', () async {
    start(token: () async => null);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(dials, isEmpty);
    expect(LiveHeads.gaveUp, isTrue);
  });

  test(
    'a real drop reconnects; a good session resets the failure count',
    () async {
      start();
      await pumpEventQueue();
      chans.single.push({'t': 'hello', 'head': <String, int>{}, 'me': 1});
      await pumpEventQueue();
      failConnect = 2;
      chans.single.drop();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(dials.length, 4); // 1 ok, 2 refused, 1 ok
      chans.last.push({'t': 'hello', 'head': <String, int>{}, 'me': 1});
      await pumpEventQueue();
      failConnect = 2;
      chans.last.drop();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(dials.length, 7); // not given up: the earlier failures were reset
      expect(LiveHeads.gaveUp, isFalse);
    },
  );

  test('stop closes the socket and does not reconnect', () async {
    start();
    await pumpEventQueue();
    LiveHeads.stop();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(chans.single.closed, isTrue);
    expect(dials.length, 1);
  });
}
