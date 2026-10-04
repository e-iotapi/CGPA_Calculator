/// Professors are entities, never text on a course (ARCHITECTURE.md §10.1):
/// one document per person per campus, ids immutable, duplicates merged by
/// pointer (§16.3 fix 7).
library;

/// One professor on one campus.
class Professor {
  const Professor({
    required this.id,
    required this.name,
    required this.campus,
    required this.department,
    this.aliases = const [],
    this.mergedInto,
    this.mergedIds = const [],
    this.active = true,
    this.removed = false,
    this.removedByName,
  });

  /// The immutable id, the display name, and the campus and department keys.
  final String id, name, campus, department;

  /// Spellings a merge absorbed.
  final List<String> aliases;

  /// Set on an absorbed duplicate: the survivor's id.
  final String? mergedInto;

  /// On a survivor: every id merged into it. Reviews are read for
  /// `[id, ...mergedIds]`.
  final List<String> mergedIds;

  /// Whether the professor can still be picked.
  final bool active;

  /// Soft-deleted by a president or admin; kept so reviews stay named.
  final bool removed;

  /// Who removed it.
  final String? removedByName;

  /// Whether this entry was absorbed into another.
  bool get merged => mergedInto != null;

  /// The id and every merged id.
  List<String> get allIds => [id, ...mergedIds];

  /// Whether [query] matches the name or an alias, by word prefix.
  bool matches(String query) {
    final q = nameTokens(query);
    if (q.isEmpty) return true;
    final mine = {
      ...nameTokens(name),
      for (final a in aliases) ...nameTokens(a),
    };
    return q.every(mine.contains);
  }

  /// Reads a professor document's data.
  static Professor fromMap(String id, Map m) => Professor(
    id: id,
    name: m['name'] as String? ?? '',
    campus: m['campus'] as String? ?? '',
    department: m['department'] as String? ?? '',
    aliases: [for (final a in m['aliases'] as List? ?? const []) '$a'],
    mergedInto: m['mergedInto'] as String?,
    mergedIds: [for (final a in m['mergedIds'] as List? ?? const []) '$a'],
    active: m['active'] as bool? ?? true,
    removed: m['removed'] as bool? ?? false,
    removedByName:
        (m['removedBy'] as Map?)?['name'] as String? ??
        m['removedByName'] as String?,
  );

  /// JSON-safe, for `cacheFirst`: [fromMap] reads it back.
  Map<String, dynamic> toMap() => {
    'name': name,
    'campus': campus,
    'department': department,
    'aliases': aliases,
    'mergedInto': mergedInto,
    'mergedIds': mergedIds,
    'active': active,
    'removed': removed,
    'removedByName': removedByName,
  };
}

/// Lowercased words of [name] and each of their prefixes, titles dropped:
/// "Dr. R. Menon" → r, m, me, men, meno, menon. What `array-contains`
/// searches (§16.3 fix 14).
Set<String> nameTokens(String name) {
  const titles = {'dr', 'prof', 'mr', 'ms', 'mrs'};
  final words = name
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty && !titles.contains(w));
  return {
    for (final w in words)
      for (var i = 1; i <= w.length && i <= 12; i++) w.substring(0, i),
  };
}

/// The exact same name, ignoring case and surrounding whitespace (BUG-14):
/// always one person, so adding it again is blocked rather than warned.
bool sameName(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

/// Two names that are probably one person: same surname and a compatible
/// first initial. Shown before Add, so nobody types a name twice.
bool likelySame(String a, String b) {
  List<String> words(String s) =>
      s
          .toLowerCase()
          .split(RegExp(r'[^a-z]+'))
          .where(
            (w) =>
                w.isNotEmpty && !{'dr', 'prof', 'mr', 'ms', 'mrs'}.contains(w),
          )
          .toList();
  final x = words(a), y = words(b);
  if (x.isEmpty || y.isEmpty || x.last != y.last) return false;
  if (x.length == 1 || y.length == 1) return true;
  return x.first[0] == y.first[0];
}

/// Professors that can be picked: not removed, not merged, active.
List<Professor> livePicks(List<Professor> all) => [
  for (final p in all)
    if (!p.removed && !p.merged && p.active) p,
];

/// The first non-merged professor whose name words equal, or contain (or are
/// contained by), [name]'s words, at least two words; null when none.
Professor? duplicateOf(String name, Iterable<Professor> all) {
  Set<String> words(String s) => {
    for (final w in s.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
      if (w.isNotEmpty && !{'dr', 'prof', 'mr', 'ms', 'mrs'}.contains(w)) w,
  };
  final mine = words(name);
  for (final p in all) {
    if (p.merged) continue;
    final t = words(p.name);
    if (t.length < 2 || mine.length < 2) continue;
    if (t.containsAll(mine) || mine.containsAll(t)) return p;
  }
  return null;
}
