/// Bulk upload of resource links as `pointer.resources.v1` JSON. Like the
/// eval-scheme importer: parse and check the whole file, preview what is
/// added and what is already there, then write. One bad row rejects the
/// file, and the error names the row.
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/resources/resource.dart';

/// The `schema` value a resources JSON file must carry.
const resourcesSchema = 'pointer.resources.v1';

/// Shipped beside the upload button, for turning any list of links into the
/// file. "Never invent a title" keeps a made-up name off a real link.
const resourcesPrompt =
    '''Turn the links I give you into one JSON object and nothing else. No prose, no markdown fences, no explanation.

Use exactly this shape: `{"schema":"pointer.resources.v1","links":[…]}`. Each link is `{"url","title","course"}`.

Rules you must follow:
- `url` is the link exactly as given, starting with https:// or http://.
- **Never invent a title.** Give `title` only when the text around the link says what it is (for example "PYQs for EEE F311" next to it); otherwise leave the field out. At most 120 characters.
- `course` is the course code exactly as printed, including the space: "CS F301", not "CSF301". Leave it out when the link is for the whole department rather than one course.
- One entry per link. Keep every link, even if two look alike.''';

/// The file failed a check; nothing is imported. [message] names the row.
class ResourceImportError implements Exception {
  const ResourceImportError(this.message);

  /// What is wrong, naming the row.
  final String message;
  @override
  String toString() => message;
}

/// One link from the file. `course` null is a department link; `guessed`
/// says the title was worked out from the address.
typedef BulkLink = ({String url, String title, bool guessed, String? course});

/// Reads [source] for [dept] on [campus]. [courses] are the course ids the
/// department manages. Throws [ResourceImportError] naming the first bad row.
List<BulkLink> parseResourceFile(
  String source, {
  required String campus,
  required String dept,
  required Set<String> courses,
}) {
  final Object? json;
  try {
    json = jsonDecode(source);
  } on FormatException {
    throw const ResourceImportError('This is not JSON.');
  }
  if (json is! Map<String, dynamic> || json['schema'] != resourcesSchema) {
    throw const ResourceImportError(
      'The file must be a JSON object with "schema": "$resourcesSchema".',
    );
  }
  for (final (k, want) in [('campus', campus), ('department', dept)]) {
    final v = json[k];
    if (v != null && v != want) {
      throw ResourceImportError(
        'The file is for $k "$v", but this page is "$want".',
      );
    }
  }
  final rows = json['links'];
  if (rows is! List || rows.isEmpty) {
    throw const ResourceImportError('"links" must be a list with one link.');
  }
  return [
    for (final (i, row) in rows.indexed) _link(i + 1, row, dept, courses),
  ];
}

BulkLink _link(int n, Object? row, String dept, Set<String> courses) {
  if (row is! Map<String, dynamic>) {
    throw ResourceImportError('Link $n is not an object.');
  }
  final url = row['url'];
  if (url is! String || url.trim().length > 500 || hostOf(url) == null) {
    throw ResourceImportError('Link $n: "$url" is not a web address.');
  }
  final title = row['title'];
  if (title != null && title is! String) {
    throw ResourceImportError('Link $n: "title" must be text.');
  }
  final t = (title as String?)?.trim() ?? '';
  if (t.length > 120) {
    throw ResourceImportError('Link $n: the title is over 120 characters.');
  }
  final course = row['course'];
  if (course != null && (course is! String || !courses.contains(course))) {
    throw ResourceImportError('Link $n: $course is not a $dept course.');
  }
  return (
    url: url.trim(),
    title: t.isEmpty ? guessTitle(url) : t,
    guessed: t.isEmpty,
    course: course as String?,
  );
}

/// A name from the address alone: "Midsem 2023 solutions" from
/// `…/Midsem_2023_solutions.pdf`, "Drive folder", "YouTube video", else the
/// site's name.
String guessTitle(String url) {
  final u = Uri.parse(url.trim());
  final host = hostOf(url)!;
  final path = u.path;
  final named = switch (host) {
    'youtube.com' || 'm.youtube.com' || 'youtu.be' =>
      path.contains('playlist') ? 'YouTube playlist' : 'YouTube video',
    'drive.google.com' =>
      path.contains('/folders/') ? 'Drive folder' : 'Drive file',
    'docs.google.com' => switch (path.split('/').elementAtOrNull(1)) {
      'spreadsheets' => 'Google Sheet',
      'presentation' => 'Google Slides',
      'forms' => 'Google Form',
      _ => 'Google Doc',
    },
    _ => null,
  };
  if (named != null) return named;
  final last = u.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
  final words =
      Uri.decodeComponent(last)
          .replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '')
          .replaceAll(RegExp(r'[-_+.]+'), ' ')
          .trim();
  // An id (`1aBcD3…`) or a bare number says nothing; the site's name does.
  final looksLikeId = !words.contains(' ') && words.length > 16;
  if (words.length < 3 || looksLikeId || !RegExp('[A-Za-z]').hasMatch(words)) {
    return host;
  }
  final t = words[0].toUpperCase() + words.substring(1);
  return t.length > 120 ? t.substring(0, 120) : t;
}

/// Splits [links] into what would be added and what is already on that
/// course or department, in [existing] or earlier in the file.
({List<BulkLink> fresh, List<BulkLink> already}) planLinks(
  List<BulkLink> links,
  Iterable<Resource> existing,
) {
  final seen = <String>{
    for (final r in existing)
      if (!r.removed) ...[
        if (r.onDepartment) '|${normaliseUrl(r.url)}',
        for (final c in r.courseIds) '$c|${normaliseUrl(r.url)}',
      ],
  };
  final fresh = <BulkLink>[], already = <BulkLink>[];
  for (final l in links) {
    final key = '${l.course ?? ''}|${normaliseUrl(l.url)}';
    (seen.add(key) ? fresh : already).add(l);
  }
  return (fresh: fresh, already: already);
}
