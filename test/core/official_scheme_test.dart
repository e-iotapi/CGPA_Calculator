import 'dart:io';

import 'package:cgpa_calculator/core/grading/official_scheme.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:cgpa_calculator/core/models/semester_kind.dart';
import 'package:cgpa_calculator/core/storage/marks.dart';
import 'package:cgpa_calculator/core/storage/offerings.dart';
import 'package:cgpa_calculator/core/storage/overrides.dart';
import 'package:cgpa_calculator/course.dart';
import 'package:cgpa_calculator/features/marks/official.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _id = 'CS F372';

OfferedComponent _comp(
  String id,
  String name,
  double weight, {
  double outOf = 30,
  double? average,
  String? date,
}) => OfferedComponent(
  id: id,
  name: name,
  weight: weight,
  average: average,
  parts: [OfferedPart(name: '', outOf: outOf, date: date)],
);

Offering _off(
  List<OfferedComponent> components, {
  int at = 1000,
  double? courseAverage,
}) => Offering(
  courseId: _id,
  campus: 'goa',
  term: '2026-27-1',
  components: components,
  updatedAt: at,
  courseAverage: courseAverage,
);

Evaluative _mine(
  String name,
  double weight, {
  double? marks,
  double outOf = 30,
  String? source,
  bool seeded = false,
}) => Evaluative(
  courseId: _id,
  name: name,
  weight: weight,
  sourceId: source,
  seeded: seeded,
  parts: [EvalPart(name: '', outOf: outOf, marks: marks)],
);

SchemeUpdate _apply(
  List<(String, Evaluative)> mine,
  Offering off, {
  Map<String, int> detached = const {},
  CourseConfig? config,
  bool seen = true,
}) => applyOffering(
  courseId: _id,
  mine: mine,
  config: config,
  off: off,
  detached: detached,
  seen: seen,
);

void main() {
  group('terms', () {
    test('a semester label is a term for the batch', () {
      expect(termOf(24, '1 - 1'), '2024-25-1');
      expect(termOf(24, '2 - 2'), '2025-26-2');
      expect(termOf(23, 'PS 1'), '2024-25-S');
      expect(termOf(23, 'ST 1'), '2025-26-S');
      expect(termOf(24, 'Custom'), isNull);
      expect(termLabel('2026-27-1'), '2026-27 Sem 1');
      expect(termLabel('2026-27-S'), '2026-27 Summer');
    });

    test('the running term follows the calendar', () {
      expect(currentTerm(DateTime(2026, 9, 27)), '2026-27-1');
      expect(currentTerm(DateTime(2027, 2, 1)), '2026-27-2');
      expect(currentTerm(DateTime(2027, 6, 15)), '2026-27-S');
    });
  });

  group('applying an offering', () {
    test('untouched seeds give way to a published scheme', () {
      final u = _apply([
        ('a', _mine('Quiz 1', 0, outOf: 0, seeded: true)),
        ('b', _mine('Midsem', 0, outOf: 0)), // older data: no flag
        ('c', _mine('Quiz 2', 5, outOf: 0, seeded: true)), // edited
      ], _off([_comp('mid', 'Mid Semester', 30)]));
      expect(u.delete, ['a', 'b']);
      expect(u.add.single.sourceId, 'mid');
      expect(u.add.single.weight, 30);
    });

    test('no scheme published: seeds stay', () {
      final u = _apply([
        ('a', _mine('Quiz 1', 0, outOf: 0, seeded: true)),
      ], _off([]));
      expect(u.delete, isEmpty);
    });

    test('the student\'s own component of the same name is linked once', () {
      final same = _apply([
        ('k', _mine('Midsem', 30, marks: 20)),
      ], _off([_comp('mid', 'Mid Semester', 30)]));
      expect(same.save['k']!.sourceId, 'mid');
      expect(same.save['k']!.name, 'Mid Semester');
      expect(same.detach, isEmpty);

      // Different values: linked, but theirs, and shown as differing.
      final differs = _apply([
        ('k', _mine('Mid-sem', 25, marks: 20)),
      ], _off([_comp('mid', 'Mid Semester', 30)]));
      expect(differs.save['k']!.sourceId, 'mid');
      expect(differs.save['k']!.weight, 25);
      expect(differs.detach, {componentGranule('mid'): 0});
    });

    test('an official component follows updates and keeps its marks', () {
      final u = _apply([
        ('k', _mine('Mid Semester', 30, marks: 21, source: 'mid')),
      ], _off([_comp('mid', 'Midsem Exam', 35, outOf: 40, average: 18)]));
      final e = u.save['k']!;
      expect([e.name, e.weight, e.parts.single.outOf], ['Midsem Exam', 35, 40]);
      expect(e.parts.single.marks, 21);
      expect(e.average, 18);
    });

    test('a component made theirs is left alone, and a newer official one '
        'is noticed', () {
      final detached = {componentGranule('mid'): 500};
      final off = _off([_comp('mid', 'Mid Semester', 35)]);
      final u = _apply(
        [('k', _mine('Mid Semester', 30, source: 'mid'))],
        off,
        detached: detached,
      );
      expect(u.save, isEmpty);
      expect(staleGranules(detached, off), [componentGranule('mid')]);
      expect(staleGranules({componentGranule('mid'): 1000}, off), isEmpty);
    });

    test('its average can be theirs while its weight updates', () {
      final u = _apply(
        [('k', _mine('Mid Semester', 30, source: 'mid')..average = 12)],
        _off([_comp('mid', 'Mid Semester', 35, average: 15)]),
        detached: {componentAverageGranule('mid'): 1000},
      );
      expect(u.save['k']!.weight, 35);
      expect(u.save['k']!.average, 12);
    });

    test('a component that left the scheme goes, unless it holds marks', () {
      final u = _apply([
        ('empty', _mine('Quiz', 5, source: 'q')),
        ('marked', _mine('Lab', 5, marks: 4, source: 'lab')),
      ], _off([_comp('mid', 'Mid Semester', 30)]));
      expect(u.delete, ['empty']);
    });

    test('a component removed after making it theirs stays removed', () {
      final u = _apply(
        [],
        _off([_comp('mid', 'Mid Semester', 30)]),
        detached: {componentGranule('mid'): 1000},
      );
      expect(u.add, isEmpty);
    });

    test('the course average: a different typed one is kept on first sight, '
        'then the official one follows', () {
      final typed = CourseConfig(courseId: _id, classAverage: 60);
      final first = _apply(
        [],
        _off([], courseAverage: 55),
        config: typed,
        seen: false,
      );
      expect(first.detach, {courseAverageGranule: 0});
      final later = _apply(
        [],
        _off([], courseAverage: 58),
        config: CourseConfig(courseId: _id, classAverage: 55),
      );
      expect(later.config!.classAverage, 58);
    });

    test('an edit names what it changes', () {
      final a = _mine('Mid Semester', 25);
      expect(
        structuralChange(a, _mine('Mid Semester', 30), true),
        'Weight 25% → 30%',
      );
      expect(
        structuralChange(a, _mine('Mid Semester', 25, outOf: 40), true),
        'Out of 30 → 40',
      );
      expect(
        structuralChange(a, _mine('Mid Semester', 25, marks: 20), true),
        isNull,
        reason: 'marks never detach anything',
      );
    });
  });

  test('semester kinds', () {
    Course c(String id, String title) => Course(
      title: title,
      id: id,
      credits: 3,
      grade1: 10,
      grade2: -2,
      discipline: 'A7',
      sem: '4 - 2',
      elective: 'CDC',
    );
    expect(semesterKind('3 - 1', [c('CS F301', 'PPL')]), SemesterKind.regular);
    expect(semesterKind('ST 1', []), SemesterKind.summer);
    expect(semesterKind('PS 1', []), SemesterKind.practiceSchool);
    expect(
      semesterKind('4 - 2', [c('BITS F412', 'Practice School II')]),
      SemesterKind.practiceSchool,
    );
  });

  group('stored', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('official');
      Hive.init(dir.path);
      registerMarksAdapters();
      await Hive.openBox('settingsBox');
      await Hive.openBox(marksBoxName);
      await openOfferings();
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('applying writes marks, and reattaching restores the official '
        'value', () async {
      await seedDefaultComponents(_id, 'Operating Systems');
      final off = _off([_comp('mid', 'Mid Semester', 30)]);
      await applyOfficial(_id, off);
      var evals = evaluativesFor(_id);
      expect(evals.map((e) => e.$2.name), ['Mid Semester']);
      expect(seenOfficial(_id), isTrue);

      final (key, e) = evals.single;
      e.weight = 40;
      await saveEvaluative(e, key: key);
      await detach(_id, {componentGranule('mid'): off.updatedAt});
      await applyOfficial(_id, off);
      expect(evaluativesFor(_id).single.$2.weight, 40);

      await reattach(_id, (g) => ofComponent(g, 'mid'));
      await applyOfficial(_id, off);
      expect(evaluativesFor(_id).single.$2.weight, 30);
      expect(detachedFor(_id), isEmpty);
    });

    test('keep mine answers the notice', () async {
      await detach(_id, {componentGranule('mid'): 10});
      await keepMine(_id, 2000);
      expect(detachedFor(_id), {componentGranule('mid'): 2000});
    });

    test('an offering is read once per max age, a missing one too', () async {
      var reads = 0;
      final source = _Source(() {
        reads++;
        return _off([_comp('mid', 'Mid Semester', 30)]);
      });
      final t0 = DateTime(2026, 9, 27, 10);
      await refreshOffering(source, _id, 'goa', '2026-27-1', now: t0);
      await refreshOffering(
        source,
        _id,
        'goa',
        '2026-27-1',
        now: t0.add(const Duration(hours: 1)),
      );
      expect(reads, 1);
      expect(cachedOffering(_id, 'goa', '2026-27-1')!.components, hasLength(1));
      await refreshOffering(
        source,
        _id,
        'goa',
        '2026-27-1',
        now: t0.add(const Duration(hours: 13)),
      );
      expect(reads, 2);
    });
  });
}

class _Source implements OfferingSource {
  _Source(this.read);
  final Offering? Function() read;

  @override
  Future<Offering?> get(String courseId, String campus, String term) async =>
      read();
}
