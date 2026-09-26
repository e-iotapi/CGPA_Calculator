/// Reads the ERP "Performance Sheet" PDF from its positioned text.
///
/// pdf.js hands back every cell as its own text item with a position, so a
/// row is the items at one height beside a course code, and its semester is
/// the nearest section heading above it in the same half of the page.
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/grading/grade_scale.dart';
import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:cgpa_calculator/core/models/semesters.dart';

/// One text item on a page. [y] grows downward.
class PdfText {
  const PdfText(this.page, this.x, this.y, this.width, this.text);
  final int page;
  final double x, y, width;
  final String text;
}

/// Parses what `window.pickPdfText` returns: `{width, items: [[page, x, y,
/// width, text], …]}`.
({double width, List<PdfText> items}) pdfTextFromJson(String json) {
  final m = jsonDecode(json) as Map<String, dynamic>;
  return (
    width: (m['width'] as num).toDouble(),
    items: [
      for (final i in m['items'] as List)
        PdfText(
          (i[0] as num).toInt(),
          (i[1] as num).toDouble(),
          (i[2] as num).toDouble(),
          (i[3] as num).toDouble(),
          i[4] as String,
        ),
    ],
  );
}

/// One course on the sheet.
class SheetRow {
  const SheetRow({
    required this.sem,
    required this.id,
    required this.title,
    required this.units,
    this.grade,
    this.tag,
    this.retake = false,
  });

  /// The app's semester, e.g. "2 - 1" or "PS 1".
  final String sem;

  /// "CS F211", single-spaced.
  final String id;

  /// As printed: upper case and abbreviated.
  final String title;
  final double units;

  /// The letter as printed; null while the course is still running.
  final String? grade;

  /// HEL, DEL or EL, when the sheet gives one.
  final String? tag;

  /// Marked R: a repeat of an earlier attempt, which it replaces.
  final bool retake;
}

class PerformanceSheet {
  const PerformanceSheet({
    required this.rows,
    this.studentId,
    this.cgpa,
    this.unplaced = const [],
    this.needs = const {},
  });

  /// Completed and registered courses, oldest first, retaken attempts
  /// already dropped.
  final List<SheetRow> rows;
  final String? studentId;
  final double? cgpa;

  /// Section headings that match no semester the app has, e.g. a summer
  /// term after the first year.
  final List<String> unplaced;

  /// Electives the degree requires, by tag (HEL, DEL, EL), from the sheet's
  /// "Count of … Required, Completed" lines.
  final Map<String, Need> needs;

  /// [needs] for [degree], or null when the sheet has none.
  ElectiveNeeds? electiveNeeds(String degree) =>
      needs.isEmpty
          ? null
          : ElectiveNeeds(
            degree: degree,
            hel: needs['HEL'],
            del: needs['DEL'],
            el: needs['EL'],
          );

  /// 2023B3A70802G → 23.
  int? get batch => switch (studentId) {
    final id? => int.tryParse(id.substring(2, 4)),
    null => null,
  };

  /// 2023B3A70802G → "B3A7"; 2023A7PS0123G → "--A7"; 2023B3PS… → "B3--".
  String? get discipline {
    final id = studentId;
    if (id == null) return null;
    final a = id.substring(4, 6), b = id.substring(6, 8);
    if (b != 'PS') return '$a$b';
    return a.startsWith('B') ? '$a--' : '--$a';
  }
}

final _studentId = RegExp(r'^\d{4}[A-Z0-9]{4}\d{4}[A-Z]$');
final _heading = RegExp(r'^(FIRST|SECOND) SEMESTER (\d{4})-\d{4}$');
final _summer = RegExp(r'^SUMMER TERM (\d{4})-\d{4}$');
final _code = RegExp(r'^([A-Z]{2,5})\s+([A-Z]\d{3}[A-Z]?)$');
final _units = RegExp(r'^\d+(\.\d+)?$');
const _tags = {'HEL', 'DEL', 'EL'};
final _needs = RegExp(r'^Count of (Electives|Units) Required');

/// The app semester for a heading, or null when there is none.
String? _semFor(String heading, int batchYear, String discipline) {
  final String? sem;
  if (_heading.firstMatch(heading) case final m?) {
    final year = int.parse(m.group(2)!) - batchYear + 1;
    sem = '$year - ${m.group(1) == 'FIRST' ? 1 : 2}';
  } else if (_summer.firstMatch(heading) case final m?) {
    // "SUMMER TERM 2024-2025" is the 2023 batch's first summer, after the
    // first year: PS 1. Each later summer is ST 1, ST 2 and so on.
    final nth = int.parse(m.group(1)!) - batchYear;
    sem = nth == 1 ? 'PS 1' : (nth > 1 ? 'ST ${nth - 1}' : null);
  } else {
    sem = null;
  }
  return sem != null && semestersFor(discipline).contains(sem) ? sem : null;
}

/// Reads [items] from a sheet [pageWidth] wide. [batch] and [discipline] are
/// used when the sheet's student id cannot be read.
PerformanceSheet parsePerformanceSheet(
  List<PdfText> items, {
  required double pageWidth,
  required int batch,
  required String discipline,
}) {
  // Everything from "Pending Courses" on lists what is left to take.
  final end =
      items.where((i) => i.text.startsWith('Pending Courses')).firstOrNull;
  bool before(PdfText i) =>
      end == null || i.page < end.page || (i.page == end.page && i.y < end.y);
  final live = items.where(before).toList();

  final id =
      live.map((i) => i.text.trim()).where(_studentId.hasMatch).firstOrNull;
  final sheet = PerformanceSheet(rows: const [], studentId: id);
  final batchYear = 2000 + (sheet.batch ?? batch);
  final disc = sheet.discipline ?? discipline;

  int side(PdfText i) => i.x + i.width / 2 < pageWidth / 2 ? 0 : 1;
  final headings = [
    for (final i in live)
      if (_heading.hasMatch(i.text.trim()) || _summer.hasMatch(i.text.trim()))
        i,
  ];

  double? cgpa;
  final label = live.where((i) => i.text.trim() == 'CGPA:').firstOrNull;
  if (label != null) {
    cgpa =
        live
            .where((i) => i.page == label.page && (i.y - label.y).abs() < 3)
            .where((i) => i.x > label.x)
            .map((i) => double.tryParse(i.text.trim()))
            .nonNulls
            .firstOrNull;
  }

  // "Count of Electives Required, Completed  HEL 3 1  DEL 10 7  EL 0 1": the
  // first number after each tag is what the degree requires.
  final required = <String, Map<String, int>>{};
  for (final label in live) {
    final kind = _needs.firstMatch(label.text.trim())?.group(1);
    if (kind == null) continue;
    final line =
        live
            .where(
              (i) =>
                  i.page == label.page &&
                  (i.y - label.y).abs() < 3 &&
                  i.x > label.x,
            )
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));
    String? tag;
    for (final i in line) {
      final t = i.text.trim();
      if (_tags.contains(t)) {
        tag = t;
      } else if (tag != null && double.tryParse(t) != null) {
        required.putIfAbsent(tag, () => {})[kind] = double.parse(t).round();
        tag = null;
      }
    }
  }
  final needs = {
    for (final MapEntry(key: tag, value: n) in required.entries)
      tag: (courses: n['Electives'] ?? 0, units: n['Units'] ?? 0),
  };

  final rows = <SheetRow>[];
  final unplaced = <String>{};
  for (final c in live) {
    final m = _code.firstMatch(c.text.trim());
    if (m == null) continue;
    // The nearest heading above, in the same half; a table that runs onto the
    // next page keeps the last heading of the previous one.
    final heading = headings
        .where(
          (h) =>
              side(h) == side(c) &&
              (h.page < c.page || (h.page == c.page && h.y < c.y)),
        )
        .fold<PdfText?>(
          null,
          (best, h) =>
              best == null ||
                      h.page > best.page ||
                      (h.page == best.page && h.y > best.y)
                  ? h
                  : best,
        );
    if (heading == null) continue;
    final sem = _semFor(heading.text.trim(), batchYear, disc);
    if (sem == null) {
      unplaced.add(heading.text.trim());
      continue;
    }

    final cells =
        live
            .where(
              (i) =>
                  i != c &&
                  i.page == c.page &&
                  side(i) == side(c) &&
                  (i.y - c.y).abs() < 2 &&
                  i.x > c.x,
            )
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));
    final title = <String>[];
    double? units;
    String? grade, tag;
    var retake = false;
    for (final cell in cells) {
      final t = cell.text.trim();
      if (units == null) {
        if (_units.hasMatch(t)) {
          units = double.parse(t);
        } else {
          title.add(t);
        }
      } else if (t == 'R') {
        retake = true;
      } else if (_tags.contains(t)) {
        tag = t;
      } else {
        grade ??= t;
      }
    }
    if (units == null) continue;
    rows.add(
      SheetRow(
        sem: sem,
        id: '${m.group(1)} ${m.group(2)}',
        title: title.join(' '),
        units: units,
        grade: grade,
        tag: tag,
        retake: retake,
      ),
    );
  }

  final order = semestersFor(disc);
  rows.sort((a, b) => order.indexOf(a.sem).compareTo(order.indexOf(b.sem)));
  // A retake replaces every earlier attempt at the same course.
  final kept = [
    for (final (i, r) in rows.indexed)
      if (!rows.skip(i + 1).any((later) => later.retake && later.id == r.id)) r,
  ];
  return PerformanceSheet(
    rows: kept,
    studentId: id,
    cgpa: cgpa,
    unplaced: unplaced.toList(),
    needs: needs,
  );
}

/// The stored value for a printed grade; null for one the app does not know.
int? gradeValueOf(String? letter) =>
    letter == null ? GradeCode.clr : gradeValues[letter];
