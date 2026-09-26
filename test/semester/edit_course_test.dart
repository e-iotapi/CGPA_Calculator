import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/cgpa.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/semester/edit_course_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _course = Course(
  title: 'A' * 30 + ' ' + 'B' * 29,
  id: 'CS F372',
  credits: 3,
  grade1: 9,
  grade2: 8,
  discipline: 'A7',
  sem: '3 - 1',
  elective: 'CDC2',
);

Future<Future<CourseEdit?> Function()> _open(
  WidgetTester t, {
  double scale = 1,
  Profile? profile = Profile.actual,
}) async {
  CourseEdit? result;
  var done = false;
  t.view.physicalSize = const Size(320, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppPalette.light.materialTheme,
      builder:
          (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home: Scaffold(
        body: Builder(
          builder:
              (c) => TextButton(
                onPressed: () async {
                  result = await showEditCourseSheet(
                    c,
                    course: _course,
                    discipline: 'A7--',
                    profile: profile,
                  );
                  done = true;
                },
                child: const Text('open'),
              ),
        ),
      ),
    ),
  );
  return () async => done ? result : null;
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('edit sheet at 320px, text ×$scale; save keeps grade2', (
      t,
    ) async {
      final result = await _open(t, scale: scale);
      await t.pump();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final list =
          find
              .descendant(
                of: find.byType(EditCourseSheet),
                matching: find.byType(Scrollable),
              )
              .first;
      await t.drag(list, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(find.text('GRADE · ACTUAL'), findsOneWidget);
      await t.tap(find.text('B'));
      await t.pump();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      final e = await result();
      expect(e?.removed, isFalse);
      expect(e?.saved?.grade1, reversegradecalc('B'));
      expect(e?.saved?.grade2, 8);
      expect(e?.saved?.elective, Elective.cdc2.tag);
    });
  }

  testWidgets('remove asks first', (t) async {
    final result = await _open(t);
    await t.pump();
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    await t.tap(find.text('Keep'));
    await t.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    await t.tap(find.text('Remove'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove').last);
    await t.pumpAndSettle();
    expect((await result())?.removed, isTrue);
  });

  testWidgets('no grade editing in Compare', (t) async {
    await _open(t, profile: null);
    await t.pump();
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.textContaining('Switch to Actual or Expected'), findsOneWidget);
  });
}
