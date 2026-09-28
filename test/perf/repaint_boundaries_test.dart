// UI_OPT O4.3/O4.4: things that move on their own sit in their own layer.
import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/features/semester/widgets/grade_menu.dart';
import 'package:cgpa_calculator/features/semester/widgets/semester_pills.dart';
import 'package:cgpa_calculator/shared/layout/responsive.dart';
import 'package:cgpa_calculator/shared/widgets/app_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [f]'s widget has a RepaintBoundary within [levels] widgets above.
bool boundaryAbove(WidgetTester t, Finder f, {int levels = 2}) {
  var found = false;
  var depth = 0;
  t.element(f).visitAncestorElements((e) {
    if (e.widget is RepaintBoundary) found = true;
    return !found && ++depth < levels;
  });
  return found;
}

Future<void> pump(WidgetTester t, Widget home) => t.pumpWidget(
  MaterialApp(theme: AppPalette.light.materialTheme, home: home),
);

void main() {
  testWidgets('the semester pill strip', (t) async {
    await pump(
      t,
      Scaffold(
        body: SemesterPills(
          semesters: const ['1 - 1', '1 - 2', '2 - 1'],
          selected: '1 - 1',
          onSelected: (_) {},
        ),
      ),
    );
    expect(boundaryAbove(t, find.byType(ListView)), isTrue);
  });

  testWidgets('the grade menu card', (t) async {
    await pump(t, const Scaffold(body: Center(child: GradeMenu(current: 9))));
    final card = find.descendant(
      of: find.byType(GradeMenu),
      matching: find.byType(Container),
    );
    expect(boundaryAbove(t, card.first), isTrue);
  });

  testWidgets('the floating nav fade', (t) async {
    await pump(
      t,
      ResponsiveScaffold(
        destinations: const [
          NavDestination(icon: Icons.home_outlined, label: 'Actual'),
          NavDestination(icon: Icons.more_horiz_rounded, label: 'More'),
        ],
        selectedIndex: 0,
        onSelected: (_) {},
        body: const SizedBox.expand(),
      ),
    );
    final fade = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient is LinearGradient,
    );
    final stack = find.ancestor(of: fade, matching: find.byType(Stack)).first;
    expect(boundaryAbove(t, stack), isTrue);
  });
}
