/// Which course codes are one course.
///
/// Every code is a node. An edge joins two codes that are the same course:
/// cross-listed by departments ("BITS F493" and "ECON F355", Business
/// Analysis and Valuation), or renumbered ("ME F110", "ME F112"). A
/// connected group is one course, so a grade under any of its codes counts
/// once, wherever any code of it is asked for.
library;

import 'package:cgpa_calculator/core/models/course_names.dart';
import 'package:cgpa_calculator/mastercourselist.dart';

/// Titles several departments give to separate courses: each department's
/// project or thesis is its own course.
const _notOneCourse = {
  'designproject',
  'labproject',
  'studyproject',
  'specialprojects',
  'thesis',
  'ticprojects',
  'practiceschooli',
  'practiceschoolii',
  'projectonorganisationalaspects',
};

String _titleKey(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class CourseGraph {
  /// [edges] as pairs of codes; any spelling of a code will do.
  CourseGraph(Iterable<(String, String)> edges) {
    for (final (a, b) in edges) {
      final x = normalizeCourseId(a.trim()), y = normalizeCourseId(b.trim());
      if (x == y) continue;
      (_adjacent[x] ??= {}).add(y);
      (_adjacent[y] ??= {}).add(x);
    }
    // Each connected group, found once by a walk from its first code.
    for (final start in _adjacent.keys) {
      if (_group.containsKey(start)) continue;
      final group = <String>{start};
      final queue = [start];
      while (queue.isNotEmpty) {
        for (final n in _adjacent[queue.removeLast()]!) {
          if (group.add(n)) queue.add(n);
        }
      }
      final frozen = Set<String>.unmodifiable(group);
      for (final id in group) {
        _group[id] = frozen;
      }
    }
  }

  /// Codes sharing a title in [list] are joined, except the titles in
  /// [_notOneCourse].
  factory CourseGraph.fromTitles(Iterable<Mastercourselist> list) {
    final byTitle = <String, List<String>>{};
    for (final m in list) {
      final key = _titleKey(m.title);
      if (_notOneCourse.contains(key)) continue;
      (byTitle[key] ??= []).add(m.id);
    }
    return CourseGraph([
      for (final ids in byTitle.values)
        for (final id in ids.skip(1)) (ids.first, id),
    ]);
  }

  final _adjacent = <String, Set<String>>{};
  final _group = <String, Set<String>>{};

  /// Every code of [id]'s course, [id] included.
  Set<String> linked(String id) {
    final n = normalizeCourseId(id.trim());
    return _group[n] ?? {n};
  }

  /// The codes joined to [id] directly.
  Set<String> neighbours(String id) =>
      _adjacent[normalizeCourseId(id.trim())] ?? const {};

  bool same(String a, String b) =>
      linked(a).contains(normalizeCourseId(b.trim()));

  /// One code standing for the whole course, for counting it once.
  String canonical(String id) {
    final all = linked(id).toList()..sort();
    return all.first;
  }

  /// Of [id]'s codes, the first whose department is in [departments];
  /// [id] itself when none is.
  String preferred(String id, Set<String> departments) =>
      linked(
        id,
      ).where((c) => departments.contains(c.split(' ').first)).firstOrNull ??
      normalizeCourseId(id.trim());
}

/// The graph of every course on offer.
final courseGraph = CourseGraph.fromTitles(mcourselist);
