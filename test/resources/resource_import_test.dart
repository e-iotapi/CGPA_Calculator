import 'dart:convert';

import 'package:cgpa_calculator/core/resources/resource.dart';
import 'package:cgpa_calculator/core/resources/resource_import.dart';
import 'package:flutter_test/flutter_test.dart';

String file(List<Map<String, Object?>> links, {Map<String, Object?>? extra}) =>
    jsonEncode({'schema': resourcesSchema, 'links': links, ...?extra});

List<BulkLink> parse(String s) => parseResourceFile(
  s,
  campus: 'goa',
  dept: 'ELEC',
  courses: {'EEE F311', 'EEE F211'},
);

Matcher rejects(String part) => throwsA(
  isA<ResourceImportError>().having(
    (e) => e.message,
    'message',
    contains(part),
  ),
);

Resource link(String url, {String? course, bool pinned = false}) => Resource(
  id: url,
  title: 'x',
  url: url,
  campus: 'goa',
  department: 'ELEC',
  scope: course == null ? 'department' : 'course',
  courseIds: course == null ? const [] : [course],
  pinnedToDepartment: pinned,
);

void main() {
  test('titles are optional; a missing one is guessed and marked', () {
    final l = parse(
      file([
        {'url': 'https://x.edu/notes/Midsem_2023-solutions.pdf'},
        {
          'url': ' https://drive.google.com/drive/folders/1aBcD ',
          'title': 'PYQs',
        },
        {
          'url': 'https://drive.google.com/file/d/1aBcDeFgHiJkLmNoP/view',
          'course': 'EEE F311',
        },
      ]),
    );
    expect(l.map((e) => (e.title, e.guessed, e.course)), [
      ('Midsem 2023 solutions', true, null),
      ('PYQs', false, null),
      ('Drive file', true, 'EEE F311'),
    ]);
    expect(l[1].url, 'https://drive.google.com/drive/folders/1aBcD');
  });

  test('guessed names', () {
    expect(guessTitle('https://www.youtube.com/watch?v=abc'), 'YouTube video');
    expect(
      guessTitle('https://youtube.com/playlist?list=P'),
      'YouTube playlist',
    );
    expect(
      guessTitle('https://drive.google.com/drive/folders/1a'),
      'Drive folder',
    );
    expect(
      guessTitle('https://docs.google.com/spreadsheets/d/1/edit'),
      'Google Sheet',
    );
    expect(
      guessTitle('https://docs.google.com/document/d/1/edit'),
      'Google Doc',
    );
    expect(guessTitle('https://notion.so/1a2b3c4d5e6f7a8b9c0d'), 'notion.so');
    expect(guessTitle('https://example.com/'), 'example.com');
    expect(guessTitle('https://example.com/2023'), 'example.com');
    expect(
      guessTitle('https://x.org/Signals%20and%20Systems'),
      'Signals and Systems',
    );
  });

  test('one bad row rejects the file and is named', () {
    expect(() => parse('nope'), rejects('not JSON'));
    expect(() => parse('{"links": []}'), rejects('schema'));
    expect(() => parse(file([])), rejects('one link'));
    expect(
      () => parse(
        file([
          {'url': 'https://a.com/x'},
          {'url': 'ftp://a.com/x'},
        ]),
      ),
      rejects('Link 2'),
    );
    expect(
      () => parse(
        file([
          {'url': 'https://localhost/x'},
        ]),
      ),
      rejects('Link 1'),
    );
    expect(
      () => parse(
        file([
          {'url': 'https://a.com/x', 'course': 'CS F301'},
        ]),
      ),
      rejects('CS F301 is not a ELEC course'),
    );
    expect(
      () => parse(
        file([
          {'url': 'https://a.com/x', 'title': 'x' * 121},
        ]),
      ),
      rejects('120'),
    );
    expect(
      () => parse(
        file(
          [
            {'url': 'https://a.com/x'},
          ],
          extra: {'campus': 'pilani'},
        ),
      ),
      rejects('pilani'),
    );
    expect(
      parse(
        file(
          [
            {'url': 'https://a.com/x'},
          ],
          extra: {'campus': 'goa', 'department': 'ELEC'},
        ),
      ),
      hasLength(1),
    );
  });

  test(
    'a link already on that course or department, or twice in the file, is skipped',
    () {
      final l = parse(
        file([
          {'url': 'https://a.com/dept'},
          {'url': 'http://www.a.com/dept/'},
          {'url': 'https://a.com/dept', 'course': 'EEE F311'},
          {'url': 'https://a.com/c', 'course': 'EEE F311'},
          {'url': 'https://a.com/c', 'course': 'EEE F211'},
          {'url': 'https://a.com/gone'},
        ]),
      );
      final p = planLinks(l, [
        link('https://a.com/c', course: 'EEE F311'),
        link('https://a.com/gone').copyWith(removed: true),
      ]);
      expect(p.fresh.map((e) => '${e.course}|${e.url}'), [
        'null|https://a.com/dept',
        'EEE F311|https://a.com/dept',
        'EEE F211|https://a.com/c',
        'null|https://a.com/gone',
      ]);
      expect(p.already.map((e) => e.url), [
        'http://www.a.com/dept/',
        'https://a.com/c',
      ]);
    },
  );
}
