// U5: the Your reviews filter pills (pure function).
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/core/reviews/review.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/reviews/mine_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Review _r(String id) => Review(
  id: 'r-$id',
  courseId: id,
  stars: 4,
  recommend: true,
  campus: 'goa',
  term: '2025-26-1',
);

Course _c(String id, String tag) => Course(
  title: id,
  id: id,
  credits: 3,
  grade1: 9,
  grade2: -2,
  discipline: 'A7',
  sem: '2 - 1',
  elective: tag,
);

void main() {
  final all = [_r('CS F211'), _r('EEE F211'), _r('HSS F101'), _r('GONE F1')];
  const taking = {'CS F211', 'HSS F101'};
  final electives = electiveIds([
    _c('CS F211', Elective.cdc1.tag),
    _c('EEE F211', Elective.open.tag),
    _c('HSS F101', Elective.humanity.tag),
  ], '----');

  List<String> ids(MineFilter f) => [
    for (final r in filterMine(all, f, taking: taking, electives: electives))
      r.courseId,
  ];

  test('electiveIds counts every elective category, never core', () {
    expect(electives, {'EEE F211', 'HSS F101'});
  });

  test('All is every review; the others narrow it', () {
    expect(MineFilter.values.first, MineFilter.all);
    expect(ids(MineFilter.all), ['CS F211', 'EEE F211', 'HSS F101', 'GONE F1']);
    expect(ids(MineFilter.thisSemester), ['CS F211', 'HSS F101']);
    expect(ids(MineFilter.electives), ['EEE F211', 'HSS F101']);
  });

  test('nothing taken: This semester is empty', () {
    expect(
      filterMine(all, MineFilter.thisSemester, taking: {}, electives: {}),
      isEmpty,
    );
  });
}
