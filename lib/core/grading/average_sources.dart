/// Which class average is in play, and why (ARCHITECTURE.md §8). At each
/// level separately — the course, each component, each part — a number the
/// student typed wins, then the published one, then the sum of the parts.
library;

import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/grading/official_scheme.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:cgpa_calculator/core/models/offering.dart';

/// "14", "13.90": as the Marks screen writes them.
String _m(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);

enum AverageSource {
  yours('Yours'),
  official('Official'),
  fromParts('From parts');

  const AverageSource(this.label);
  final String label;
}

/// A resolved average, where it came from, and the published figure it
/// stands in front of (for "the official 13.90 is not used").
typedef SourcedAverage =
    ({double value, AverageSource source, double? official});

/// Typed-or-official: [value] is what is stored, [official] what is
/// published, [granule] the override that would hold a typed one.
SourcedAverage? _stored(
  double? value,
  double? official,
  String? granule,
  Map<String, int> detached,
) {
  if (value == null) return null;
  final mine =
      official == null ||
      granule == null ||
      detached.containsKey(granule) ||
      value != official;
  return (
    value: value,
    source: mine ? AverageSource.yours : AverageSource.official,
    official: official,
  );
}

SourcedAverage? courseAverageOf(
  double? stored,
  Offering? off,
  Map<String, int> detached,
) => _stored(stored, off?.courseAverage, courseAverageGranule, detached);

SourcedAverage? componentAverageOf(
  Evaluative e,
  Offering? off,
  Map<String, int> detached,
) {
  final id = e.sourceId;
  final official = id == null ? null : off?.component(id)?.average;
  final typed = _stored(
    e.average,
    official,
    id == null ? null : componentAverageGranule(id),
    detached,
  );
  if (typed != null) return typed;
  final derived = componentAverage(e);
  if (derived == null) return null;
  return (
    value: derived.value,
    source: AverageSource.fromParts,
    official: official,
  );
}

SourcedAverage? partAverageOf(
  Evaluative e,
  int i,
  Offering? off,
  Map<String, int> detached,
) {
  final id = e.sourceId;
  final parts = id == null ? null : off?.component(id)?.parts;
  final official = parts != null && i < parts.length ? parts[i].average : null;
  return _stored(
    e.parts[i].average,
    official,
    id == null ? null : partAverageGranule(id, i),
    detached,
  );
}

/// The one line under an average: "Published by your CR", "You typed this;
/// the official 13.90 is not used", "Worked out from the 3 part averages".
String sourceLine(SourcedAverage a, {int parts = 0}) => switch (a.source) {
  AverageSource.official => 'Published by your CR',
  AverageSource.yours =>
    a.official == null
        ? 'You typed this'
        : 'You typed this; the official ${_m(a.official!)} is not used',
  AverageSource.fromParts =>
    'Worked out from the ${parts == 0 ? '' : '$parts '}part averages',
};

/// The averages whose typed value differs from [before]'s on an official
/// component: each granule to detach, with a line for the warning.
Map<String, String> averageChanges(Evaluative before, Evaluative after) {
  final id = before.sourceId;
  if (id == null) return const {};
  String show(double? v) => v == null ? 'blank' : _m(v);
  return {
    if (before.average != after.average)
      componentAverageGranule(id):
          'Class average ${show(before.average)} → ${show(after.average)}',
    for (final (i, p) in before.parts.indexed)
      if (i < after.parts.length && p.average != after.parts[i].average)
        partAverageGranule(id, i):
            '${p.name.isEmpty ? 'Class' : p.name} average '
            '${show(p.average)} → ${show(after.parts[i].average)}',
  };
}
