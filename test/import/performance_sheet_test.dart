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

  /// A "Count of …" line: each tag followed by its numbers.
  void needs(String label, List<String> numbers) {
    text(23.4, label);
    final per = numbers.length ~/ 3;
    for (final (i, tag) in ['HEL', 'DEL', 'EL'].indexed) {
      final x = 226 + i * 110.0;
      text(x, tag);
      for (var j = 0; j < per; j++) {
        text(x + 41 + j * 36, numbers[i * per + j]);
      }
    }
    y += 11;
  }

  /// A pending line: up to two courses, each code split in two items the
  /// way the pending section prints it.
  void pendingLine(List<(String, String, String, String)> courses) {
    for (final (i, (dept, no, title, units)) in courses.indexed) {
      final x = 20 + i * 253.0;
      text(x, dept);
      text(x + 20, no);
      text(x + 54, title);
      text(x + 210, units);
    }
    y += 9.3;
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
  s.needs('Count of Electives Required, Completed', [
    '3',
    '1',
    '10',
    '7',
    '0',
    '1',
  ]);
  s.needs('Count of Units Required, Completed', [
    '8',
    '3',
    '30',
    '21',
    '0',
    '3',
  ]);
  s.text(23.4, 'Pending Courses (To be eligible for graduation)');
  s.y += 20;
  s.band('FIRST SEMESTER 2026-2027', [_r('CS F303', 'COMPUTER NETWORKS', 'A')]);
  s.pendingLine([('CS', 'F363', 'COMPILER CONSTRUCTION', '3.0')]);
  s.pendingLine([
    ('BITS', 'F412', 'PRACTICE SCHOOL II', '20.0'),
    ('BITS', 'F421T', 'THESIS', '16.0'),
  ]);
  s.pendingLine([('BITS', 'F413', 'PRACTICE SCHOOL II', '20.0')]);
  // The pending section's own counts are what is left, not what is required.
  s.needs('Count of Electives', ['2', '3', '0']);
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
      // The first summer term is PS 1, the next ST 1.
      expect(row('BITS F221').sem, 'PS 1');
      expect(row('ECON F212').sem, 'ST 1');
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

    test('reads what each elective tag requires', () {
      expect(sheet.needs, {
        'HEL': (courses: 3, units: 8),
        'DEL': (courses: 10, units: 30),
        'EL': (courses: 0, units: 0),
      });
      expect(sheet.degreeNeeds('B3A7')!.del, (courses: 10, units: 30));
    });

    test('reads pending courses, codes split or whole', () {
      expect(sheet.pending.map((p) => p.id), [
        'CS F303',
        'CS F363',
        'BITS F412',
        'BITS F421T',
        'BITS F413',
      ]);
      expect(sheet.pending[1].title, 'COMPILER CONSTRUCTION');
      expect(sheet.pending[2].units, 20);
    });

    test('core needs: untagged courses, pending ones, and one PS II', () {
      // Taken, untagged: MATH F111 3, ME F112 2, CS F111 4, BITS F225 3,
      // MATH F211 3, BITS F221 5, ECON F212 3 (the retake), CS F213 4.
      // Pending: CS F303 3, CS F363 3. PS II 20; the thesis is not added.
      expect(sheet.cdc, (courses: 11, units: 53));
      expect(sheet.degreeNeeds('B3A7')!.cdc, sheet.cdc);
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
      expect(after('ECON F354')!.elective, Elective.del1.tag);
      expect(after('CS F213')!.grade1, GradeCode.clr);
      expect(after('CS F213')!.title, isNot('OBJECT ORIENTED PROG'));
    });

    test('untagged courses are core, in the half that offers them', () {
      expect(after('CS F213')!.elective, Elective.cdc2.tag);
      expect(after('BITS F225')!.elective, 'CDCN');
      // Stored as core already: keeps its half.
      expect(after('CS F111')!.elective, 'CDC');
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

  group('planImport on data that disagrees with the sheet', () {
    final sheet = _sample().parse();
    final plan = planImport(sheet, <dynamic, Course>{
      // Graded under the chart's old code; the sheet has ME F112.
      'ME F110': _stored('ME F110', '1 - 1', 10, title: 'Workshop Practice'),
      // Graded, but never taken that semester.
      'X F999': _stored('X F999', '1 - 2', 4),
      // Same course twice, both graded.
      1: _stored('CS F111', '1 - 2', 9),
      2: _stored('CS F111', '1 - 2', 9),
      // A guess for a semester still to come.
      'CS F303': _stored('CS F303', '4 - 2', 10),
      // Still running, with a guessed Actual grade.
      'CS F213': _stored('CS F213', '3 - 1', 8),
    }, discipline: 'B3A7');

    test('removes what the sheet does not list and clears guesses', () {
      // ME F110 is ME F112 renumbered: replaced, not dropped.
      expect(plan.dropped, contains('X F999 (1 - 2)'));
      expect(plan.dropped, isNot(contains('ME F110 (1 - 1)')));
      expect(plan.remove, containsAll(['ME F110', 'X F999']));
      expect(
        [1, 2].where(plan.remove.contains),
        hasLength(1),
        reason: 'one CS F111 stays, the duplicate goes',
      );
      expect(plan.cleared, ['CS F303 (4 - 2)']);
      expect(plan.put['CS F303']!.grade1, GradeCode.clr);
      expect(plan.running, ['CS F213']);
    });

    test('the CGPA comes out as the sheet\'s own courses give', () {
      final fromSheet = planImport(sheet, const {}, discipline: 'B3A7');
      expect(plan.cgpaAfter, fromSheet.cgpaAfter);
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
