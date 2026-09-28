/// One named link (ARCHITECTURE.md §6): a flat, campus-scoped document; the
/// hierarchy a student sees is a view over these (§10.4).
library;

/// The host shown under a link ("drive.google.com", "en.wikipedia.org"),
/// or null when [url] is not an http(s) link with a dotted host. Any website
/// may be linked; a bad one is what Reported is for (UI_REBUILD_HANDOFF.md
/// §3.10). The rules' `linkOk` checks the same shape.
String? hostOf(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || (u.scheme != 'https' && u.scheme != 'http')) return null;
  final host = u.host.toLowerCase();
  if (!host.contains('.')) return null;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// The address with scheme, `www.`, query string and trailing slash
/// stripped: the same Drive folder under three titles is one link (§6).
String normaliseUrl(String url) {
  var s = url.trim().toLowerCase();
  s = s.replaceFirst(RegExp(r'^[a-z]+://'), '');
  s = s.replaceFirst(RegExp(r'^www\.'), '');
  s = s.split('#').first.split('?').first;
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// "video" for YouTube, "doc" for Docs, "folder" for Drive, else "link".
String kindOf(String host) => switch (host) {
  'youtube.com' || 'youtu.be' => 'video',
  'docs.google.com' => 'doc',
  'drive.google.com' => 'folder',
  _ => 'link',
};

class Resource {
  const Resource({
    required this.id,
    required this.title,
    required this.url,
    required this.campus,
    required this.department,
    this.scope = 'department',
    this.courseIds = const [],
    this.pinnedToDepartment = false,
    this.addedByName = '',
    this.addedByEmail = '',
    this.addedAt = 0,
    this.removed = false,
  });

  final String id, title, url, campus, department;

  /// 'department' or 'course'.
  final String scope;

  /// The course it was added for first, then any course that picked it
  /// from the department's list — the same document, never a copy.
  final List<String> courseIds;

  /// A course link also listed under its department (rollup, §6).
  final bool pinnedToDepartment;
  final String addedByName, addedByEmail;

  /// Milliseconds since the epoch.
  final int addedAt;
  final bool removed;

  String get host => hostOf(url) ?? Uri.tryParse(url)?.host ?? url;
  String get kind => kindOf(host);
  bool get isCourse => scope == 'course';

  /// A course link rolled up into the department's list.
  bool get rolledUp => isCourse && pinnedToDepartment;
  bool get onDepartment => !isCourse || pinnedToDepartment;
  String? get fromCourse => isCourse ? courseIds.firstOrNull : null;

  Resource copyWith({
    String? title,
    String? url,
    List<String>? courseIds,
    bool? pinnedToDepartment,
    bool? removed,
  }) => Resource(
    id: id,
    title: title ?? this.title,
    url: url ?? this.url,
    campus: campus,
    department: department,
    scope: scope,
    courseIds: courseIds ?? this.courseIds,
    pinnedToDepartment: pinnedToDepartment ?? this.pinnedToDepartment,
    addedByName: addedByName,
    addedByEmail: addedByEmail,
    addedAt: addedAt,
    removed: removed ?? this.removed,
  );

  /// The shape cached in Hive; Firestore adds its own bookkeeping.
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'url': url,
    'host': host,
    'kind': kind,
    'campus': campus,
    'department': department,
    'scope': scope,
    'courseIds': courseIds,
    'pinnedToDepartment': pinnedToDepartment,
    'addedBy': {'name': addedByName, 'email': addedByEmail},
    'addedAt': addedAt,
    'removed': removed,
  };

  static Resource fromMap(Map m, [String? id]) {
    final by = m['addedBy'] as Map? ?? const {};
    final at = m['addedAt'];
    return Resource(
      id: id ?? m['id'] as String,
      title: m['title'] as String? ?? '',
      url: m['url'] as String? ?? '',
      campus: m['campus'] as String? ?? '',
      department: m['department'] as String? ?? '',
      scope: m['scope'] as String? ?? 'department',
      courseIds: [for (final c in m['courseIds'] as List? ?? const []) '$c'],
      pinnedToDepartment: m['pinnedToDepartment'] as bool? ?? false,
      addedByName: by['name'] as String? ?? '',
      addedByEmail: by['email'] as String? ?? '',
      addedAt:
          at is int
              ? at
              : at is num
              ? at.toInt()
              : (at as dynamic)?.millisecondsSinceEpoch as int? ?? 0,
      removed: m['removed'] as bool? ?? false,
    );
  }
}

/// Why a link was reported (§16.3 fix 3).
enum ReportReason {
  broken('It doesn\'t open'),
  wrong('Wrong course'),
  spam('Shouldn\'t be shared'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

/// The open reports on one link, read by whoever can fix it.
class ResourceFlag {
  const ResourceFlag({
    required this.resourceId,
    required this.campus,
    required this.department,
    required this.courseIds,
    required this.count,
    required this.reasons,
    this.open = true,
  });

  final String resourceId, campus, department;
  final List<String> courseIds;
  final int count;
  final Map<String, int> reasons;
  final bool open;

  /// The most common reason, for the row's line.
  ReportReason get top {
    final e = reasons.entries.toList()..sort((a, b) => b.value - a.value);
    return ReportReason.values.firstWhere(
      (r) => r.name == e.firstOrNull?.key,
      orElse: () => ReportReason.other,
    );
  }

  static ResourceFlag fromMap(String id, Map m) => ResourceFlag(
    resourceId: id,
    campus: m['campus'] as String? ?? '',
    department: m['department'] as String? ?? '',
    courseIds: [for (final c in m['courseIds'] as List? ?? const []) '$c'],
    count: (m['count'] as num?)?.toInt() ?? 0,
    reasons: {
      for (final e in (m['reasons'] as Map? ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    },
    open: m['open'] as bool? ?? false,
  );
}

/// Department links first, then the rollup; newest first within each.
List<Resource> departmentList(Iterable<Resource> all) =>
    all.where((r) => !r.removed && r.onDepartment).toList()..sort((a, b) {
      final k = (a.rolledUp ? 1 : 0) - (b.rolledUp ? 1 : 0);
      return k != 0 ? k : b.addedAt - a.addedAt;
    });

List<Resource> courseList(Iterable<Resource> all, String courseId) =>
    all.where((r) => !r.removed && r.courseIds.contains(courseId)).toList()
      ..sort((a, b) => b.addedAt - a.addedAt);

/// Whether a new course link for [url] should roll up: only when the
/// department does not already list the same address (§6).
bool shouldRollUp(Iterable<Resource> department, String url) {
  final n = normaliseUrl(url);
  return !department.any(
    (r) => !r.removed && r.onDepartment && normaliseUrl(r.url) == n,
  );
}
