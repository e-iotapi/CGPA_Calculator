import 'package:flutter/material.dart';
import 'package:cgpa_calculator/features/semester/semester_controller.dart';

/// Marks as typed: "14", "2.76".
String marks2(double v) =>
    v == v.roundToDouble() ? formatCredits(v) : v.toStringAsFixed(2);

/// "1.56 ahead of the class" / "4.20 behind". The words carry the meaning,
/// not the colour.
String deltaWords(double d, [String tail = '']) {
  final t = tail.isEmpty ? '' : ' $tail';
  return '${d.abs().toStringAsFixed(2)} ${d < 0 ? 'behind' : 'ahead'}$t';
}

/// ▲ / ▼ as an icon — the font has no arrow glyphs.
IconData deltaIcon(double d) =>
    d < 0 ? Icons.arrow_drop_down_rounded : Icons.arrow_drop_up_rounded;

/// "25 Aug" from an ISO date string.
String shortDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${m[d.month - 1]}';
}

/// "2026-09-26".
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
