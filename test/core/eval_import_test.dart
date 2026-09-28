import 'dart:convert';

import 'package:cgpa_calculator/core/grading/eval_import.dart';
import 'package:cgpa_calculator/core/models/offering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String file(List<Map<String, Object?>> courses, {String campus = 'Goa'}) =>
      jsonEncode({
        'schema': 'pointer.eval.v1',
        'campus': campus,
        'term': '2026-27-1',
        'courses': courses,
      });

  final quiz = {
    'name': 'Quiz 1',
    'weight': 10,
    'outOf': 20,
    'date': '2026-09-08',
    'rule': {'type': 'all'},
  };
  final midsem = {
    'name': 'Midsem',
    'weight': 30,
    'rule': {'type': 'bestNofM', 'n': 1, 'm': 2},
    'parts': [
      {'name': 'Part A', 'outOf': 30},
      {'name': 'Part B', 'outOf': 30},
    ],
  };

  EvalFile parse(String s) => parseEvalFile(
    s,
    campus: 'goa',
    known: (id) => id.startsWith('CS '),
    inScope: (id) => id != 'CS F999',
  );

  test('reads the documented shape', () {
    final f = parse(
      file([
        {
          'code': 'CS  F301',
          'professors': ['Dr. R. Menon'],
          'weighted': true,
          'components': [quiz, midsem],
          'notes': 'compre weight not stated',
        },
      ]),
    );
    expect(f.term, '2026-27-1');
    final c = f.courses.single;
    expect(c.courseId, 'CS F301');
    expect(c.assigned, 40);
    expect(c.notes, 'compre weight not stated');
    expect(c.professorNames, ['Dr. R. Menon']);
    expect(c.components.first.parts.single.date, '2026-09-08');
    expect(c.components.last.countBest, 1);
    expect(c.components.last.parts, hasLength(2));
  });

  test('one bad row rejects the whole file, and says which', () {
    Matcher names(String s) => throwsA(
      isA<EvalImportError>().having((e) => e.message, 'message', contains(s)),
    );
    final missingWeight = {'name': 'Compre', 'outOf': 100};
    expect(
      () => parse(
        file([
          {
            'code': 'CS F301',
            'components': [quiz],
          },
          {
            'code': 'CS F211',
            'components': [quiz, missingWeight],
          },
        ]),
      ),
      names('courses[1] (CS F211) components[1] (Compre)'),
    );
    expect(() => parse('not json'), names('Not JSON'));
    expect(() => parse(file([], campus: 'Pilani')), names('uploading for goa'));
    expect(
      () => parse(
        file([
          {
            'code': 'ME F341',
            'components': [quiz],
          },
        ]),
      ),
      names('no such course'),
    );
    expect(
      () => parse(
        file([
          {
            'code': 'CS F999',
            'components': [quiz],
          },
        ]),
      ),
      names('outside what you maintain'),
    );
    expect(
      () => parse(
        file([
          {
            'code': 'CS F301',
            'components': [quiz],
          },
          {
            'code': 'CS F301',
            'components': [quiz],
          },
        ]),
      ),
      names('first at courses[0]'),
    );
  });

  test('matching a component by name keeps its id and average', () {
    final existing = Offering(
      courseId: 'CS F301',
      campus: 'goa',
      term: '2026-27-1',
      updatedAt: 5,
      professors: const ['p1'],
      components: const [
        OfferedComponent(
          id: 'c1',
          name: 'quiz 1',
          weight: 15,
          average: 12.4,
          parts: [OfferedPart(name: '', outOf: 20)],
        ),
      ],
    );
    final f = parse(
      file([
        {
          'code': 'CS F301',
          'components': [quiz, midsem],
        },
      ]),
    );
    final next = schemeFor(
      f.courses.single,
      campus: 'goa',
      term: f.term,
      existing: existing,
    );
    expect(next.components.first.id, 'c1');
    expect(next.components.first.average, 12.4);
    expect(next.components.last.id, 'c2');
    expect(next.professors, ['p1']);
    expect(effectOf(next, existing), ImportEffect.change);
    expect(effectOf(next, null), ImportEffect.create);
    expect(effectOf(next, next), ImportEffect.same);
  });

  test('gradedOutOf is read, kept on a re-import without it, and checked', () {
    final existing = Offering(
      courseId: 'CS F301',
      campus: 'goa',
      term: '2026-27-1',
      updatedAt: 5,
      components: const [],
      outOf: 300,
    );
    final withScale =
        parse(
          file([
            {
              'code': 'CS F301',
              'gradedOutOf': 200,
              'components': [quiz],
            },
          ]),
        ).courses.single;
    expect(withScale.outOf, 200);
    expect(
      schemeFor(
        withScale,
        campus: 'goa',
        term: '2026-27-1',
        existing: existing,
      ).outOf,
      200,
    );
    final without =
        parse(
          file([
            {
              'code': 'CS F301',
              'components': [quiz],
            },
          ]),
        ).courses.single;
    expect(
      schemeFor(
        without,
        campus: 'goa',
        term: '2026-27-1',
        existing: existing,
      ).outOf,
      300,
    );
    expect(
      () => parse(
        file([
          {
            'code': 'CS F301',
            'gradedOutOf': -1,
            'components': [quiz],
          },
        ]),
      ),
      throwsA(isA<EvalImportError>()),
    );
  });

  test('writes go five courses a chunk', () {
    final c = chunked(List.generate(12, (i) => i));
    expect(c.map((l) => l.length), [5, 5, 2]);
  });

  test('the extraction prompt carries its two guard lines', () {
    expect(evalPrompt, contains('**Never invent a value.**'));
    expect(evalPrompt, contains('Do not adjust them to fit.'));
  });
}
