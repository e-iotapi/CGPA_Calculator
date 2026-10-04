/// One named link (ARCHITECTURE.md §6): a flat, campus-scoped document; the
/// hierarchy a student sees is a view over these (§10.4).
library;

/// How long a contributor's link may wait for approval (B7).
const contributorWindow = Duration(days: 15);

/// One contributor submission awaiting approval (`pending/<campus>|<dept>`).
class PendingBatch {
  const PendingBatch({
    required this.id,
    required this.campus,
    required this.dept,
    required this.email,
    required this.username,
    required this.at,
    required this.links,
  });

  /// The batch id, its campus and department keys, the contributor's
  /// address and username.
  final String id, campus, dept, email, username;

  /// When it was submitted (epoch ms).
  final int at;

  /// The links still awaiting a decision.
  final List<({String id, String title, String url})> links;

  /// JSON-safe, for the cache.
  Map<String, dynamic> toMap() => {
    'id': id,
    'campus': campus,
    'dept': dept,
    'email': email,
    'username': username,
    'at': at,
    'links': [
      for (final l in links) {'id': l.id, 'title': l.title, 'url': l.url},
    ],
  };

  /// Reads [toMap].
  static PendingBatch fromMap(Map m) => PendingBatch(
    id: m['id'] as String,
    campus: m['campus'] as String,
    dept: m['dept'] as String,
    email: m['email'] as String? ?? '',
    username: m['username'] as String? ?? '',
    at: (m['at'] as num?)?.toInt() ?? 0,
    links: [
      for (final l in m['links'] as List)
        (
          id: (l as Map)['id'] as String,
          title: l['title'] as String? ?? '',
          url: l['url'] as String? ?? '',
        ),
    ],
  );
}

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

/// A named link, on a department's list or on a course's.
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
    this.approved = true,
    this.publishedAt,
    this.batchId = '',
    this.rejectedReason = '',
  });

  /// B7: a contributor's link is live but `approved: false` until a
  /// president approves it; absent (true) on every other link.
  final bool approved;

  /// Contributor links only: when published (epoch ms) and the submission
  /// batch it belongs to.
  final int? publishedAt;

  /// The submission batch id, and the reason a rejected link was removed.
  final String batchId, rejectedReason;

  /// Whether readers hide the link: unapproved and past its 15 days.
  bool hiddenAt(DateTime now) =>
      !approved &&
      publishedAt != null &&
      now.millisecondsSinceEpoch - publishedAt! > contributorWindow.inMilliseconds;

  /// The document id, the title and address shown, and the campus key and
  /// department key it belongs to.
  final String id, title, url, campus, department;

  /// 'department' or 'course'.
  final String scope;

  /// The course it was added for first, then any course that picked it
  /// from the department's list — the same document, never a copy.
  final List<String> courseIds;

  /// A course link also listed under its department (rollup, §6).
  final bool pinnedToDepartment;
  /// Who added the link.
  final String addedByName, addedByEmail;

  /// Milliseconds since the epoch.
  final int addedAt;

  /// Whether the link was taken down.
  final bool removed;

  /// The host shown under the link.
  String get host => hostOf(url) ?? Uri.tryParse(url)?.host ?? url;

  /// The link's [kindOf] its [host].
  String get kind => kindOf(host);

  /// Whether the link was added on a course rather than a department.
  bool get isCourse => scope == 'course';

  /// A course link rolled up into the department's list.
  bool get rolledUp => isCourse && pinnedToDepartment;
  /// Whether the link shows on its department's list.
  bool get onDepartment => !isCourse || pinnedToDepartment;

  /// The course a course link was added for, or `null` for a department link.
  String? get fromCourse => isCourse ? courseIds.firstOrNull : null;

  /// Copies this link with the given fields changed.
  Resource copyWith({
    String? title,
    String? url,
    List<String>? courseIds,
    bool? pinnedToDepartment,
    bool? removed,
    bool? approved,
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
    approved: approved ?? this.approved,
    publishedAt: publishedAt,
    batchId: batchId,
    rejectedReason: rejectedReason,
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
    if (!approved) 'approved': false,
    if (publishedAt != null) 'publishedAt': publishedAt,
    if (batchId.isNotEmpty) 'batchId': batchId,
    if (rejectedReason.isNotEmpty) 'rejectedReason': rejectedReason,
  };

  /// Reads a link from Firestore or the Hive cache; [id] overrides `m['id']`.
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
      approved: m['approved'] as bool? ?? true,
      publishedAt: switch (m['publishedAt']) {
        null => null,
        final num n => n.toInt(),
        final Object o => (o as dynamic).millisecondsSinceEpoch as int,
      },
      batchId: m['batchId'] as String? ?? '',
      rejectedReason: m['rejectedReason'] as String? ?? '',
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

  /// The text shown for the reason.
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

  /// The reported link, and its campus key and department key.
  final String resourceId, campus, department;

  /// The courses the link is listed on.
  final List<String> courseIds;

  /// The number of open reports.
  final int count;

  /// Report counts by [ReportReason] name.
  final Map<String, int> reasons;

  /// Whether the reports still await a decision.
  final bool open;

  /// The most common reason, for the row's line.
  ReportReason get top {
    final e = reasons.entries.toList()..sort((a, b) => b.value - a.value);
    return ReportReason.values.firstWhere(
      (r) => r.name == e.firstOrNull?.key,
      orElse: () => ReportReason.other,
    );
  }

  /// JSON-safe: [fromMap] reads it back.
  Map<String, dynamic> toMap() => {
    'campus': campus,
    'department': department,
    'courseIds': courseIds,
    'count': count,
    'reasons': reasons,
    'open': open,
  };

  /// Reads the flag document of link [id].
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

/// The links of course [courseId] in [all], newest first.
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
