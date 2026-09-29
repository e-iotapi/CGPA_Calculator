/// Professors are entities, never text on a course (ARCHITECTURE.md §10.1):
/// one document per person per campus, ids immutable, duplicates merged by
/// pointer (§16.3 fix 7).
library;

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
  });

  final String id, name, campus, department;

  /// Spellings a merge absorbed.
  final List<String> aliases;

  /// Set on an absorbed duplicate: the survivor's id.
  final String? mergedInto;

  /// On a survivor: every id merged into it. Reviews are read for
  /// `[id, ...mergedIds]`.
  final List<String> mergedIds;
  final bool active;

  bool get merged => mergedInto != null;
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

  static Professor fromMap(String id, Map m) => Professor(
    id: id,
    name: m['name'] as String? ?? '',
    campus: m['campus'] as String? ?? '',
    department: m['department'] as String? ?? '',
    aliases: [for (final a in m['aliases'] as List? ?? const []) '$a'],
    mergedInto: m['mergedInto'] as String?,
    mergedIds: [for (final a in m['mergedIds'] as List? ?? const []) '$a'],
    active: m['active'] as bool? ?? true,
  );
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
