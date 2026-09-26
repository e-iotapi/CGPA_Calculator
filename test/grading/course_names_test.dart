import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/core/models/elective.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:flutter_test/flutter_test.dart';

Course _c(String id, String sem) => Course(
  title: 'Social Conduct',
  id: id,
  credits: 0.5,
  grade1: 10,
  grade2: GradeCode.clr,
  discipline: 'B3',
  sem: sem,
  elective: 'Humanity Elective',
);

void main() {
  test('lowercase l reads as 1 in the number only', () {
    expect(normalizeCourseId('BITS F10l'), 'BITS F101');
    expect(normalizeCourseId('BITS K10l'), 'BITS K101');
    expect(normalizeCourseId('CS F372'), 'CS F372');
    expect(sameCourseId('BITS F10l', 'BITS F101'), isTrue);
  });

  test('aliases join titles; MF F221 is left alone', () {
    expect(
      displayTitle('BITS F10l', 'Social Conduct'),
      'Navigating Campus Life and Living Well / Social Conduct',
    );
    expect(
      displayTitle('MF F221', 'Mechanisms and Machines'),
      'Mechanisms and Machines',
    );
    expect(displayTitle('CS F372', 'Operating Systems'), 'Operating Systems');
    expect(courseTitleAliases.length, 8);
  });

  test('an F101 / F10l pair counts as one course, credits unchanged', () {
    final cs = [_c('BITS F101', '1 - 1'), _c('BITS F10l', '1 - 2')];
    expect(earnedCourses(Elective.humanity, cs), 1);
    expect(earnedCredits(Elective.humanity, cs), 1);
  });
}
