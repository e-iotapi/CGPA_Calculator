// "Graded out of" (UI_REBUILD_HANDOFF.md §3.2): the offering stores the
// scale; without one, every scale is the course's own units.
import 'package:cgpa_calculator/admin/offering_scale.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:flutter_test/flutter_test.dart';

Offering offering({bool weighted = true, double total = 100}) => Offering(
  courseId: 'CS F372',
  campus: 'goa',
  term: '2026-27-1',
  weighted: weighted,
  totalMarks: total,
  components: const [],
  professors: const [],
  updatedAt: 0,
);

void main() {
  test('without a stored scale, a weighted course is out of 100', () {
    expect(outOfStored, isTrue);
    expect(offeringOutOf(offering()), isNull);
    expect(scaleOf(offering()), 100);
  });

  test('a marks course is out of its total', () {
    expect(scaleOf(offering(weighted: false, total: 50)), 50);
  });

  test('withOutOf sets and clears the stored scale, and it round-trips', () {
    final o = withOutOf(offering(), 200);
    expect(offeringOutOf(o), 200);
    expect(scaleOf(o), 200);
    expect(Offering.fromMap(o.toMap()).outOf, 200);
    expect(offeringOutOf(withOutOf(o, null)), isNull);
    expect(offering().toMap().containsKey('outOf'), isFalse);
  });

  test('an average typed out of 200 is stored in percent, and back', () {
    expect(toStored(150, scale: 200, units: 100), 75);
    expect(toShown(75, scale: 200, units: 100), 150);
  });

  test('on the course\'s own scale the average is stored as typed', () {
    expect(toStored(63.5, scale: 100, units: 100), 63.5);
    expect(toStored(40, scale: 50, units: 50), 40);
  });
}
