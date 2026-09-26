import 'package:cgpa_calculator/app/theme/palette.dart';
import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/import/import_plan.dart';
import 'package:cgpa_calculator/features/import/import_preview.dart';
import 'package:cgpa_calculator/features/import/performance_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A cell of a course row: (code, title, units, grade, retake, tag).
typedef _Row = (String, String, String, String?, bool, String?);

/// Lays out a sheet the way the ERP's PDF does: two half-width tables per
/// band, one text item per cell, 612pt wide.
class _Sheet {
  final items = <PdfText>[];
  var y = 150.0;

  void text(double x, String s, {int page = 1, double? at}) =>
      items.add(PdfText(page, x, at ?? y, s.length * 4.5, s));

  void header(String id, String cgpa) {
    text(23.4, 'Student ID:', at: 100);
    text(95.4, id, at: 99.7);
    text(378.9, 'CGPA:', at: 112.5);
    text(441.9, cgpa, at: 113.1);
  }

  /// One band: a left table and optionally a right one.
  void band(
    String left,
    List<_Row> l, [
    String? right,
    List<_Row> r = const [],
  ]) {
    text(104.9, left);
    if (right != null) text(387.3, right);
    y += 10;
    text(17.5, 'Course No.');
    text(209.6, 'Units Grade');
    y += 10;
    final top = y;
    for (final (i, rows) in [l, r].indexed) {
      y = top;
      final dx = i * 287.9;
      for (final (code, title, units, grade, retake, tag) in rows) {
        text(19.7 + dx, code);
        text(74.5 + dx, title);
        text(215.1 + dx, units);
        if (grade != null) text(235.8 + dx, grade);
        if (retake) text(259.6 + dx, 'R');
        if (tag != null) text(280.2 + dx, tag);
        y += 9.3;
      }
    }
    y = top + 9.3 * (l.length > r.length ? l.length : r.length) + 20;
  }

  PerformanceSheet parse() => parsePerformanceSheet(
    items,
    pageWidth: 612,
    batch: 24,
    discipline: '--A7',
  );
}

_Row _r(
  String code,
  String title,
  String? grade, {
  String units = '3.0',
  bool retake = false,
  String? tag,
}) => (code, title, units, grade, retake, tag);

_Sheet _sample() {
  final s = _Sheet()..header('2023B3A70802G', '7.50');
  s.band(
    'FIRST SEMESTER 2023-2024',
    [
      _r('MATH F111', 'MATHEMATICS-I', 'B'),
      _r('ME F112', 'WORKSHOP PRACTICE', 'A', units: '2.0'),
    ],
    'SECOND SEMESTER 2023-2024',
    [_r('CS F111', 'COMPUTER PROGRAMMING', 'A-', units: '4.0')],
  );
  s.band(
    'FIRST SEMESTER 2024-2025',
    [
      _r('ECON F212', 'FUNDA OF FIN AND ACCOUNT', 'C'),
      _r('GS F211', 'MOD POLITICAL CONCEPTS', 'B-', tag: 'HEL'),
      _r('BITS F225', 'ENVIRONMENTAL STUDIES', 'GD'),
      _r('MATH F211', 'MATHEMATICS III', 'I'),
    ],
    'SECOND SEMESTER 2024-2025',
    [_r('ECON F354', 'DERIVATIVES & RISK MGMT', 'B', tag: 'DEL')],
  );
  s.band(
    'SUMMER TERM 2024-2025',
    [_r('BITS F221', 'PRACTICE SCHOOL I', 'A', units: '5.0')],
    'SUMMER TERM 2025-2026',
    [_r('ECON F212', 'FUNDA OF FIN AND ACCOUNT', 'A-', retake: true)],
  );
  s.band('FIRST SEMESTER 2025-2026', [
    _r('CS F213', 'OBJECT ORIENTED PROG', null, units: '4.0'),
  ]);
  s.text(23.4, 'Pending Courses (To be eligible for graduation)');
  s.y += 20;
  s.band('FIRST SEMESTER 2026-2027', [_r('CS F303', 'COMPUTER NETWORKS', 'A')]);
  return s;
}

Course _stored(
  String id,
  String sem,
  int g, {
  String title = 'x',
  double credits = 3,
}) => Course(
  title: title,
  id: id,
  credits: credits,
  grade1: g,
  grade2: GradeCode.clr,
  discipline: 'B3',
  sem: sem,
  elective: 'CDC',
);

void main() {
  group('parsePerformanceSheet', () {
    final sheet = _sample().parse();
    SheetRow row(String id) => sheet.rows.singleWhere((r) => r.id == id);

    test('reads the student, their degree and the stated CGPA', () {
      expect(sheet.studentId, '2023B3A70802G');
      expect(sheet.batch, 23);
      expect(sheet.discipline, 'B3A7');
      expect(sheet.cgpa, 7.5);
      expect(
        const PerformanceSheet(rows: [], studentId: '2023A7PS0123G').discipline,
        '--A7',
      );
      expect(
        const PerformanceSheet(rows: [], studentId: '2023B3PS0123G').discipline,
        'B3--',
      );
    });

    test('places each heading in the app\'s semesters', () {
      expect(row('MATH F111').sem, '1 - 1');
      expect(row('CS F111').sem, '1 - 2');
      expect(row('GS F211').sem, '2 - 1');
      expect(row('ECON F354').sem, '2 - 2');
      expect(row('BITS F221').sem, 'PS 1');
      expect(row('CS F213').sem, '3 - 1');
      expect(sheet.unplaced, isEmpty);
    });

    test('reads units, grades and tags; running courses have no grade', () {
      expect(row('ME F112').units, 2);
      expect(row('ME F112').title, 'WORKSHOP PRACTICE');
      expect(row('BITS F225').grade, 'GD');
      expect(row('GS F211').tag, 'HEL');
      expect(row('ECON F354').tag, 'DEL');
      expect(row('CS F213').grade, isNull);
    });

    test('a retake replaces the earlier attempt', () {
      final econ = row('ECON F212');
      expect(econ.sem, 'ST 1');
      expect(econ.grade, 'A-');
      expect(econ.retake, isTrue);
    });

    test('pending courses are left out', () {
      expect(sheet.rows.where((r) => r.id == 'CS F303'), isEmpty);
    });
  });

  group('planImport', () {
    final sheet = _sample().parse();
    final stored = <dynamic, Course>{
      // Already where the sheet has it, grade to fill in.
      'MATH F111': _stored('MATH F111', '1 - 1', GradeCode.clr),
      // Renumbered: the chart's code for Workshop Practice.
      'ME F110': _stored(
        'ME F110',
        '1 - 1',
        GradeCode.clr,
        title: 'Workshop Practice',
      ),
      // Charted a semester later than it was taken.
      'CS F111': _stored('CS F111', '2 - 1', GradeCode.clr),
      // The earlier attempt, graded, under an int key.
      7: _stored('ECON F212', '2 - 1', 6),
      // Already right.
      'BITS F221': _stored('BITS F221', 'PS 1', 10, credits: 5),
    };
    final plan = planImport(sheet, stored, discipline: 'B3A7');
    Course? after(String id) =>
        [...plan.put.values, ...plan.add].where((c) => c.id == id).firstOrNull;

    test('fills grades in place and moves chart courses', () {
      expect(after('MATH F111')!.grade1, gradeValues['B']);
      expect(after('CS F111')!.sem, '1 - 2');
      expect(after('CS F111')!.credits, 4);
      expect(plan.moved, 1);
    });

    test('a renumbered chart course is replaced, not duplicated', () {
      expect(plan.remove, contains('ME F110'));
      expect(after('ME F112')!.grade1, gradeValues['A']);
      expect(plan.renumbered, 1);
    });

    test('only the retaken attempt survives, with its grade', () {
      expect(plan.put[7]!.sem, 'ST 1');
      expect(plan.put[7]!.grade1, gradeValues['A-']);
      expect(plan.retakes, 1);
    });

    test('added courses take the master title and the sheet tag', () {
      expect(after('GS F211')!.elective, Elective.humanity.tag);
      expect(after('ECON F354')!.elective, startsWith('Disciplinary'));
      expect(after('CS F213')!.grade1, GradeCode.clr);
      expect(after('CS F213')!.title, isNot('OBJECT ORIENTED PROG'));
    });

    test('an unknown grade is reported and left ungraded', () {
      expect(plan.unknownGrades, ['MATH F211: I']);
      expect(after('MATH F211')!.grade1, GradeCode.clr);
    });

    test('an unchanged course is not rewritten, and CGPA is worked out', () {
      expect(plan.put.containsKey('BITS F221'), isFalse);
      expect(plan.unchanged, 1);
      expect(plan.cgpaAfter, isNotNull);
    });
  });

  group('ImportPreview', () {
    final sheet = _sample().parse();
    final plan = planImport(sheet, const {}, discipline: 'B3A7');

    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out at 320px, text ×$scale, and answers', (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        bool? answer;
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
            home: Builder(
              builder:
                  (c) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () async =>
                              answer = await showImportPreview(
                                c,
                                sheet: sheet,
                                plan: plan,
                              ),
                      child: const Text('open'),
                    ),
                  ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.textContaining('courses added'), findsOneWidget);
        // Nothing stored, so the CGPA differs from the sheet's 7.50.
        expect(find.textContaining('Your sheet says 7.50'), findsOneWidget);
        await t.scrollUntilVisible(
          find.text('Import'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await t.tap(find.text('Import'));
        await t.pumpAndSettle();
        expect(answer, isTrue);
      });
    }
  });
}
