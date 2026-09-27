import 'package:cgpa_calculator/core/grading/average_sources.dart';
import 'package:cgpa_calculator/core/grading/official_scheme.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const off = Offering(
    courseId: 'CS F372',
    campus: 'goa',
    term: '2026-27-1',
    updatedAt: 10,
    courseAverage: 9.8,
    components: [
      OfferedComponent(
        id: 'mid',
        name: 'Mid Semester',
        weight: 30,
        average: 13.9,
        parts: [OfferedPart(name: '', outOf: 25)],
      ),
      OfferedComponent(
        id: 'ka',
        name: 'Kernel Assignments',
        weight: 20,
        parts: [
          OfferedPart(name: 'CPU', outOf: 10, average: 7.4),
          OfferedPart(name: 'Mem', outOf: 10),
        ],
      ),
    ],
  );

  Evaluative eval(String id, List<EvalPart> parts, {double? average}) =>
      Evaluative(
        courseId: 'CS F372',
        name: id,
        weight: 10,
        parts: parts,
        average: average,
        sourceId: id,
      );

  test('yours, then official, then from parts — at each level', () {
    expect(courseAverageOf(9.8, off, {})!.source, AverageSource.official);
    final typed = courseAverageOf(10.2, off, {courseAverageGranule: 10})!;
    expect(typed.source, AverageSource.yours);
    expect(sourceLine(typed), 'You typed this; the official 9.80 is not used');
    expect(courseAverageOf(null, off, {}), isNull);

    final mid = eval('mid', [EvalPart(name: '', outOf: 25)], average: 13.9);
    expect(componentAverageOf(mid, off, {})!.source, AverageSource.official);

    final ka = eval('ka', [
      EvalPart(name: 'CPU', outOf: 10, average: 7.4),
      EvalPart(name: 'Mem', outOf: 10, average: 4.7),
    ]);
    final k = componentAverageOf(ka, off, {})!;
    expect(k.source, AverageSource.fromParts);
    expect(k.value, closeTo(12.1, 1e-9));
    expect(partAverageOf(ka, 0, off, {})!.source, AverageSource.official);
    expect(partAverageOf(ka, 1, off, {})!.source, AverageSource.yours);
  });

  test('a changed average names the granule to detach', () {
    final before = eval('ka', [
      EvalPart(name: 'CPU', outOf: 10, average: 7.4),
    ], average: 12);
    final after = eval('ka', [
      EvalPart(name: 'CPU', outOf: 10, average: 8),
    ], average: 12);
    expect(averageChanges(before, after).keys, [partAverageGranule('ka', 0)]);
    expect(averageChanges(before, before), isEmpty);
  });
}
