/// The programmes a discipline code stands for, and where they run
/// (`DISCIPLINES_GOA_HYD.md`).
library;

enum Campus {
  goa('Goa'),
  hyderabad('Hyderabad'),
  pilani('Pilani'),
  dubai('Dubai');

  const Campus(this.label);
  final String label;

  static Campus? named(String? name) =>
      values.where((c) => c.name == name).firstOrNull;
}

class Programme {
  const Programme(this.code, this.name, {this.campuses, this.gap});

  /// "A7".
  final String code;

  /// "B.E. Computer Science".
  final String name;

  /// Where it runs; null for campuses the app has no list for.
  final Set<Campus>? campuses;

  /// Why its course list is incomplete, when it is.
  final String? gap;

  /// An M.Sc.: the first half of a dual degree.
  bool get isMsc => code.startsWith('B');
}

const _goa = {Campus.goa}, _hyd = {Campus.hyderabad};
const _both = {Campus.goa, Campus.hyderabad};

const programmes = [
  Programme('A1', 'B.E. Chemical', campuses: _both),
  Programme('A2', 'B.E. Civil', campuses: _hyd),
  Programme('A3', 'B.E. Electrical & Electronics', campuses: _both),
  Programme('A4', 'B.E. Mechanical', campuses: _both),
  Programme('A5', 'B.Pharm.', campuses: _hyd),
  Programme('A7', 'B.E. Computer Science', campuses: _both),
  Programme('A8', 'B.E. Electronics and Instrumentation', campuses: _both),
  Programme('A9', 'B.E. Biotechnology', campuses: {}),
  Programme('AA', 'B.E. Electronics and Communication', campuses: _both),
  Programme('AB', 'B.E. Manufacturing', campuses: {Campus.pilani}),
  Programme('AC', 'B.E. Electronics and Computer', campuses: _goa),
  Programme('AD', 'B.E. Mathematics and Computing', campuses: _both),
  Programme(
    'AJ',
    'B.E. Environmental and Sustainability',
    campuses: _both,
    gap: 'Common core only — branch courses not in the list yet',
  ),
  Programme('B1', 'M.Sc. Biological Sciences', campuses: _both),
  Programme('B2', 'M.Sc. Chemistry', campuses: _both),
  Programme('B3', 'M.Sc. Economics', campuses: _both),
  Programme('B4', 'M.Sc. Mathematics', campuses: _both),
  Programme('B5', 'M.Sc. Physics', campuses: _both),
  Programme('B7', 'M.Sc. Semiconductor and Nanoscience', campuses: _both),
];

Programme? programmeFor(String code) =>
    programmes.where((p) => p.code == code).firstOrNull;

/// "B.E. Computer Science" for "A7"; the code itself when unknown.
String programmeName(String code) => programmeFor(code)?.name ?? code;

/// Programmes to offer on [campus]. Goa and Hyderabad have their own lists;
/// Pilani and Dubai, which the app has no list for, see every programme
/// still offered.
List<Programme> programmesAt(Campus? campus) => [
  for (final p in programmes)
    if (campus == Campus.goa || campus == Campus.hyderabad
        ? p.campuses?.contains(campus) ?? false
        : p.campuses?.isNotEmpty ?? true)
      p,
];
