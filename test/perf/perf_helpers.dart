import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts its own rebuilds. Read via `tester.state`, `find.byType(BuildCounter)`
/// and the state's `builds` field.
class BuildCounter extends StatefulWidget {
  const BuildCounter({super.key, required this.child});

  final Widget child;

  @override
  State<BuildCounter> createState() => BuildCounterState();
}

class BuildCounterState extends State<BuildCounter> {
  int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    // Depends on the ambient theme, like any real theme-reading widget, so
    // an AnimatedTheme lerp (or a themeVersion rebuild) marks it dirty.
    Theme.of(context);
    return widget.child;
  }
}

/// How many times a [BuildCounter] under [f] rebuilt while [act] runs.
Future<int> countBuilds(WidgetTester t, Future<void> Function() act) async {
  final state = t.state<BuildCounterState>(find.byType(BuildCounter));
  final before = state.builds;
  await act();
  return state.builds - before;
}

/// The nearest [RepaintBoundary] wrapping [f], if any.
Finder repaintBoundaryAround(Finder f) =>
    find.ancestor(of: f, matching: find.byType(RepaintBoundary));
