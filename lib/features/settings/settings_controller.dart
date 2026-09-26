/// Rules the old Settings screen applied, kept as functions of their inputs.
library;

import 'package:cgpa_calculator/script.dart' show degreelist, notOfferedHere;

/// What initializeCourses does with the course box on the way back home:
/// 0 keeps grades, 1 clears everything, 2 drops the A-discipline courses
/// and keeps the B ones.
typedef DisciplineChange = ({String discipline, int erase});

/// A discipline code is two halves: the first ("B3", "B-" other, "--" none)
/// is the MSc of a dual degree, the second ("A7", "--" other) the B.E.
DisciplineChange changeDiscipline(
  String current, {
  required bool dual,
  required String value,
  required int erase,
}) {
  final first = current.substring(0, 2), second = current.substring(2, 4);
  if (dual) {
    if (first == value) return (discipline: current, erase: erase);
    return (discipline: value + second, erase: 1);
  }
  if (second == value) return (discipline: current, erase: erase);
  return (
    discipline: first + value,
    erase: erase != 1 && current.startsWith('B') ? 2 : 1,
  );
}

/// Crossing the 2025 line swaps the course list, so grades are cleared.
int batchErase(int from, int to, int erase) =>
    (from < 25) != (to < 25) ? 1 : erase;

/// Empty falls back to the default name; longer than nine is cut.
String profileName(String text, String fallback) {
  final t = text.trim();
  if (t.isEmpty) return fallback;
  return t.length > 9 ? t.substring(0, 9) : t;
}

/// Picker options as (stored value, label). A code not offered at Goa or
/// Hyderabad shows only while it is [current].
List<(String, String)> disciplineOptions({
  required bool dual,
  String? current,
}) {
  final codes = [
    for (final d in degreelist)
      if (d.startsWith(dual ? 'B' : 'A') &&
          (!notOfferedHere.contains(d) || d == current))
        d,
  ];
  return [
    for (final d in codes) (d, d),
    if (dual) ...[('B-', 'Other'), ('--', 'None')] else ('--', 'Other'),
  ];
}

String disciplineLabel(String half, {required bool dual}) =>
    disciplineOptions(
      dual: dual,
    ).firstWhere((o) => o.$1 == half, orElse: () => (half, half)).$2;

/// Stored as two digits.
List<int> batchOptions(DateTime now) => [
  for (var y = 18; y <= now.year % 100 + 1; y++) y,
];

/// What a change will do, for the confirmation; null when grades stay.
String? eraseWarning(int erase) => switch (erase) {
  1 => 'This reloads the course list and clears all your grades.',
  2 =>
    'This reloads your B.E. courses and clears their grades. '
        'Your MSc grades stay.',
  _ => null,
};
