import 'dart:io';

import 'package:cgpa_calculator/core/storage/seed.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/import/import_plan.dart';
import 'package:cgpa_calculator/features/import/performance_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs only where a real sheet's text is on disk (gitignored: real grades).
void main() {
  final file = File('test/fixtures/performance_sheet.json');
  test('a real performance sheet imports to the CGPA it states', () {
    final (:width, :items) = pdfTextFromJson(file.readAsStringSync());
    final sheet = parsePerformanceSheet(
      items,
      pageWidth: width,
      batch: 24,
      discipline: '--A7',
    );
    final d = sheet.discipline!;
    final seeded = seedCourses(d, chartRows(sheet.batch!));
    final plan = planImport(sheet, {
      for (final c in seeded) c.id: c,
    }, discipline: d);
    // ignore: avoid_print
    print(
      '${sheet.rows.length} rows, ${plan.graded} graded, ${plan.add.length} '
      'added, ${plan.moved} moved, ${plan.retakes} retakes, unknown '
      '${plan.unknownGrades}, unplaced ${sheet.unplaced}, CGPA '
      '${plan.cgpaAfter} vs ${sheet.cgpa}',
    );
    expect(plan.cgpaAfter, sheet.cgpa);
    expect(sheet.needs.keys, containsAll(['HEL', 'DEL', 'EL']));

    // Data that already disagrees with the sheet still lands on its CGPA.
    Course graded(String id) =>
        seeded.firstWhere((c) => c.id == id).withGrade(1, 10);
    final messy = <dynamic, Course>{
      for (final c in seeded) c.id: c,
      'ME F110': graded('ME F110'),
      99: graded('CS F111'),
      'CS F303': graded('CS F303'),
    };
    expect(planImport(sheet, messy, discipline: d).cgpaAfter, sheet.cgpa);
  }, skip: file.existsSync() ? false : 'no local performance sheet');
}
