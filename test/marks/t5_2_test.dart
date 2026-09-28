import 'dart:io';

import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/add_evaluative_page.dart';
import 'package:cgpa_calculator/shared/widgets/app_text_field.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

EvalPart _p(String n, double? m, double o) =>
    EvalPart(name: n, marks: m, outOf: o);

Evaluative _kernel() => Evaluative(
  courseId: 'CS F372',
  name: 'Kernel Assignments',
  weight: 20,
  countBest: 2,
  parts: [
    _p('CPU Scheduling', 8, 10),
    _p('Memory Management', 6, 10),
    _p('Concurrency', 3, 10),
  ],
);

/// The section labels, top to bottom, that both paths must show.
const _sections = [
  'COMPONENT NAME',
  'WEIGHT',
  'CLASS AVERAGE',
  'One mark',
  'Several parts',
  'HOW MANY COUNT',
  'PARTS',
  'DATE',
  'YOU',
  'OUT OF',
  'AVG',
  'PART 1',
  'PART 2',
  '+ Part',
  'THIS COMPONENT GIVES YOU',
];

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_t5_2');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
    registerMarksAdapters();
    await Sync.openBoxes();
  });
  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(theme: AppPalette.light.materialTheme, home: w),
    );
    await t.pumpAndSettle();
  }

  List<double> order(WidgetTester t) => [
    for (final s in _sections) t.getTopLeft(find.text(s).first).dy,
  ];

  testWidgets('a new component has the edit layout, empty', (t) async {
    await pump(
      t,
      const AddEvaluativePage(
        courseId: 'CS F372',
        weighted: true,
        unassigned: 15,
      ),
    );
    for (final s in _sections) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    final added = order(t);
    // Every field starts empty.
    for (final f in t.widgetList<TextField>(find.byType(TextField))) {
      expect(f.controller!.text, isEmpty);
    }

    await pump(
      t,
      AddEvaluativePage(
        courseId: 'CS F372',
        weighted: true,
        unassigned: 15,
        existing: _kernel(),
        existingKey: 'k',
      ),
    );
    final edited = order(t);
    // The same sections in the same order on both paths.
    for (var i = 1; i < _sections.length; i++) {
      expect(
        added[i] >= added[i - 1],
        edited[i] >= edited[i - 1],
        reason: _sections[i],
      );
    }
  });

  testWidgets('new says new and hides Delete; edit says edit', (t) async {
    await pump(
      t,
      const AddEvaluativePage(
        courseId: 'CS F372',
        weighted: true,
        unassigned: 15,
      ),
    );
    expect(find.text('CS F372 · NEW COMPONENT'), findsOneWidget);
    expect(find.text('New component'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Add component'), findsOneWidget);
    expect(find.byTooltip('Delete component'), findsNothing);

    await pump(
      t,
      AddEvaluativePage(
        courseId: 'CS F372',
        weighted: true,
        unassigned: 15,
        existing: _kernel(),
        existingKey: 'k',
      ),
    );
    expect(find.text('CS F372 · EDIT COMPONENT'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Save'), findsOneWidget);
    expect(find.byTooltip('Delete component'), findsOneWidget);
  });

  testWidgets('One mark still switches a new component to one row', (t) async {
    await pump(
      t,
      const AddEvaluativePage(
        courseId: 'CS F372',
        weighted: true,
        unassigned: 15,
      ),
    );
    await t.tap(find.text('One mark'));
    await t.pump();
    expect(find.text('PARTS'), findsNothing);
    expect(find.text('HOW MANY COUNT'), findsNothing);
    expect(find.text('YOU'), findsOneWidget);
  });
}
