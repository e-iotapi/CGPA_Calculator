import 'dart:async';

import 'package:cgpa_calculator/admin/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// TM-16: a keyed screen opens with its prefetched or last data, refreshes
// behind it, and keeps that data when the refresh fails.
void main() {
  Widget screen(String key, Future<String> Function() load) => MaterialApp(
    home: Loaded<String>(
      cacheKey: key,
      load: load,
      builder: (_, v, _) => Text(v),
    ),
  );

  testWidgets('a prefetched screen opens with data', (tester) async {
    var loads = 0;
    final gate = Completer<String>();
    unawaited(
      prefetchLoaded('a', () {
        loads++;
        return gate.future;
      }),
    );
    await tester.pumpWidget(
      screen('a', () async {
        loads++;
        return 'x';
      }),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(loads, 1, reason: 'the screen shares the prefetch in flight');
    gate.complete('first');
    await tester.pump();
    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('a reopened screen shows its last data while refreshing', (
    tester,
  ) async {
    await tester.pumpWidget(screen('b', () async => 'old'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    final gate = Completer<String>();
    await tester.pumpWidget(screen('b', () => gate.future));
    expect(find.text('old'), findsOneWidget);
    gate.completeError('offline');
    await tester.pump();
    expect(find.text('old'), findsOneWidget);
  });

  testWidgets('a peeked value shows in the first frame', (t) async {
    final c = Completer<String>();
    await t.pumpWidget(MaterialApp(home: Loaded<String>(
      peek: () => 'saved', load: () => c.future,
      builder: (_, v, _) => Text(v))));
    expect(find.text('saved'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    c.complete('fresh'); await t.pump();
    expect(find.text('fresh'), findsOneWidget);
  });

  testWidgets('a failed load keeps the peeked value', (t) async {
    await t.pumpWidget(MaterialApp(home: Loaded<String>(
      peek: () => 'saved', load: () async => throw StateError('offline'),
      builder: (_, v, _) => Text(v))));
    await t.pump();
    expect(find.text('saved'), findsOneWidget);
  });

  testWidgets('a gated screen whose refresh fails says so and offers a retry',
      (t) async {
    var loads = 0;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Loaded<String>(
      peek: () => 'saved',
      load: () async {
        loads++;
        throw StateError('offline');
      },
      gated: (_, v, _, saved) => Text('$v ${saved ? 'off' : 'on'}'),
    ))));
    await t.pump();
    await t.pump();
    expect(find.text('saved off'), findsOneWidget);
    expect(find.textContaining("Couldn't refresh"), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500)); // the bar slides in
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(loads, 2);
  });
}
