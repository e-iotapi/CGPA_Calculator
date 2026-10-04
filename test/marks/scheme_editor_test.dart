import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/storage/courses.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/features/marks/scheme_editor_page.dart';
import 'package:cgpa_calculator/features/marks/widgets/average_sources.dart';
import 'package:cgpa_calculator/shared/widgets/tag_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_data.dart';

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  ),
  matching: find.byType(TextField),
);

void main() {
  setUpAll(seedDevice);

  testWidgets('editing an official weight asks; Keep official reverts; '
      'Make it mine tags only that row YOURS', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final course = allCourses().firstWhere((c) => c.id == takingId);
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: SchemeEditorPage(course: course),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('YOURS'), findsOneWidget, reason: 'Assignment 0');
    final officials = find.text('OFFICIAL').evaluate().length;
    expect(officials, greaterThan(1));

    final weight = _field('Kernel Assignments weight');
    await t.enterText(weight, '25');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('Make Kernel Assignments yours?'), findsOneWidget);
    await t.tap(find.text('Keep official'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(weight).controller!.text, '20');

    await t.enterText(weight, '25');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    // Detaching and saving write to Hive, which needs real time.
    await t.runAsync(() async {
      await t.tap(find.text('Make it mine'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 3; i++) {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
    }
    await t.pumpAndSettle();
    expect(find.text('YOURS'), findsNWidgets(2));
    expect(find.text('OFFICIAL'), findsNWidgets(officials - 1));
    expect(
      evaluativesFor(
        takingId,
      ).firstWhere((e) => e.$2.name == 'Kernel Assignments').$2.weight,
      25,
    );
  });

  testWidgets('average sources: each level shows its source badge', (t) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final course = allCourses().firstWhere((c) => c.id == takingId);
    final evals = [for (final (_, e) in evaluativesFor(takingId)) e];
    await t.pumpWidget(
      MaterialApp(
        theme: AppPalette.light.materialTheme,
        home: AverageSourcesPage(
          course: course,
          courseAverage: 70,
          evals: evals,
          official: takingOffering(),
          detached: const {'average.course': 1},
        ),
      ),
    );
    await t.pumpAndSettle();
    Finder badgeOf(String name) => find.descendant(
      of:
          find
              .ancestor(of: find.text(name).last, matching: find.byType(Row))
              .first,
      matching: find.byType(TagBadge),
    );
    String tagOf(String name) => t.widget<TagBadge>(badgeOf(name)).text;
    expect(tagOf(course.title), 'YOURS');
    expect(tagOf('Kernel Assignments'), 'OFFICIAL');
    expect(tagOf('Assignment 0'), 'FROM PARTS');
  });
}
