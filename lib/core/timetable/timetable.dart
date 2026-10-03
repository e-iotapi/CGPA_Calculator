/// The broadcast timetable (BUILDOUT_CONTRACTS.md B8b): one published JSON per
/// campus and semester. Numbers are read as `num` (JS has no int/double).
library;

/// The newest schema this app understands.
const timetableSchema = 1;

num _n(Object? o) => o as num;

/// One weekly slot: [d] 1 = Mon .. 6 = Sat, [s]/[e] minutes since midnight.
class TtSlot {
  const TtSlot(this.d, this.s, this.e);
  final int d, s, e;

  /// `'<d>-<s>'`, the published day and start.
  String get id => '$d-$s';

  static TtSlot fromJson(Map m) =>
      TtSlot(_n(m['d']).toInt(), _n(m['s']).toInt(), _n(m['e']).toInt());
  Map<String, dynamic> toJson() => {'d': d, 's': s, 'e': e};
}

/// A lecture, tutorial or practical section.
class TtSection {
  const TtSection({
    required this.ty,
    required this.no,
    this.prof = const [],
    this.profIds = const [],
    this.slots = const [],
    this.room,
  });
  final String ty;
  final int no;
  final List<String> prof, profIds;
  final List<TtSlot> slots;
  final String? room;

  /// `'<courseId>|<ty><no>'`.
  String key(String courseId) => '$courseId|$ty$no';

  static TtSection fromJson(Map m) => TtSection(
    ty: m['ty'] as String,
    no: _n(m['no']).toInt(),
    prof: [for (final p in (m['prof'] as List?) ?? const []) '$p'],
    profIds: [for (final p in (m['profIds'] as List?) ?? const []) '$p'],
    slots: [
      for (final s in (m['slots'] as List?) ?? const []) TtSlot.fromJson(s as Map),
    ],
    room: m['room'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'ty': ty,
    'no': no,
    'prof': prof,
    if (profIds.isNotEmpty) 'profIds': profIds,
    'slots': [for (final s in slots) s.toJson()],
    if (room != null) 'room': room,
  };
}

/// A midsem or compre: date `YYYY-MM-DD`, minutes, and the FN/AN [slot] for a compre.
class TtExam {
  const TtExam(this.d, this.s, this.e, {this.slot});
  final String d;
  final String? slot;
  final int s, e;

  static TtExam fromJson(Map m) => TtExam(
    m['d'] as String,
    _n(m['s']).toInt(),
    _n(m['e']).toInt(),
    slot: m['slot'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'd': d,
    if (slot != null) 'slot': slot,
    's': s,
    'e': e,
  };
}

class TtCourse {
  const TtCourse({
    required this.id,
    required this.title,
    this.credits,
    this.sections = const [],
    this.compre,
    this.mid,
  });
  final String id, title;
  final num? credits;
  final List<TtSection> sections;
  final TtExam? compre, mid;

  static TtCourse fromJson(String id, Map m) => TtCourse(
    id: id,
    title: m['t'] as String? ?? '',
    credits: m['cr'] as num?,
    sections: [
      for (final s in (m['sec'] as List?) ?? const []) TtSection.fromJson(s as Map),
    ],
    compre: m['compre'] == null ? null : TtExam.fromJson(m['compre'] as Map),
    mid: m['mid'] == null ? null : TtExam.fromJson(m['mid'] as Map),
  );
  Map<String, dynamic> toJson() => {
    't': title,
    if (credits != null) 'cr': credits,
    'sec': [for (final s in sections) s.toJson()],
    if (compre != null) 'compre': compre!.toJson(),
    if (mid != null) 'mid': mid!.toJson(),
  };
}

/// A dated academic event; [kind] is holiday, exam, deadline or term.
class AcademicEvent {
  const AcademicEvent(this.from, this.title, this.kind, {this.to});
  final String from;
  final String? to;
  final String title, kind;

  /// The last day, inclusive.
  String get last => to ?? from;

  static AcademicEvent fromJson(Map m) => AcademicEvent(
    m['from'] as String,
    m['title'] as String? ?? '',
    m['kind'] as String? ?? 'term',
    to: m['to'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'from': from,
    if (to != null) 'to': to,
    'title': title,
    'kind': kind,
  };
}

/// `YYYY-MM-DD` -> UTC midnight (floating dates; no DST involved).
DateTime parseDate(String d) => DateTime.parse('${d}T00:00:00Z');

/// UTC midnight -> `YYYY-MM-DD`.
String fmtDate(DateTime d) => d.toIso8601String().substring(0, 10);

class Timetable {
  Timetable({
    required this.campus,
    required this.sem,
    required this.publishedAt,
    required this.marker,
    required this.courses,
    this.events = const [],
    this.hours = const {},
    this.examSlots = const {},
  });
  final String campus, sem;
  final int publishedAt, marker;
  final Map<String, TtCourse> courses;
  final List<AcademicEvent> events;

  /// Hour code -> `[startMin, endMin]`, and FN/AN -> the same.
  final Map<String, List<int>> hours, examSlots;

  /// Throws [FormatException] for a schema newer than this app knows.
  static Timetable fromJson(Map m) {
    if (_n(m['v'] ?? 1) > timetableSchema) {
      throw const FormatException('Timetable is newer than this app: update the app');
    }
    Map<String, List<int>> spans(Object? o) => {
      for (final e in ((o as Map?) ?? const {}).entries)
        '${e.key}': [for (final x in e.value as List) _n(x).toInt()],
    };
    return Timetable(
      campus: m['campus'] as String,
      sem: m['sem'] as String,
      publishedAt: _n(m['publishedAt'] ?? 0).toInt(),
      marker: _n(m['marker'] ?? 0).toInt(),
      hours: spans(m['hours']),
      examSlots: spans(m['examSlots']),
      events: [
        for (final e in (m['events'] as List?) ?? const [])
          AcademicEvent.fromJson(e as Map),
      ],
      courses: {
        for (final e in ((m['courses'] as Map?) ?? const {}).entries)
          '${e.key}': TtCourse.fromJson('${e.key}', e.value as Map),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'v': timetableSchema,
    'campus': campus,
    'sem': sem,
    'publishedAt': publishedAt,
    'marker': marker,
    'hours': hours,
    'examSlots': examSlots,
    'events': [for (final e in events) e.toJson()],
    'courses': {for (final e in courses.entries) e.key: e.value.toJson()},
  };

  /// Courses whose id or title has every word of [q] as a word prefix; ids
  /// that start with the query first, at most 50.
  List<TtCourse> search(String q) {
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final flat = q.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    bool hit(TtCourse c) {
      final hay = '${c.id} ${c.title}'.toLowerCase().split(RegExp(r'\s+'));
      return words.every((w) => hay.any((h) => h.startsWith(w)));
    }

    final all = courses.values.where(hit).toList();
    bool idFirst(TtCourse c) =>
        c.id.toLowerCase().replaceAll(' ', '').startsWith(flat);
    return [...all.where(idFirst), ...all.where((c) => !idFirst(c))]
        .take(50)
        .toList();
  }

  /// First day of instruction: an event titled "instruction ... begin", else
  /// the earliest term event, else a guess from the semester name.
  String semStart() {
    final term = events.where((e) => e.kind == 'term').toList();
    final begin = term.where(
      (e) => RegExp(r'instruction.*begin|begin.*instruction', caseSensitive: false).hasMatch(e.title),
    );
    if (begin.isNotEmpty) return begin.first.from;
    if (term.isNotEmpty) return (term.map((e) => e.from).toList()..sort()).first;
    final y = int.tryParse(sem.substring(0, 4)) ?? 2000;
    return sem.endsWith('-2') ? '${y + 1}-01-05' : '$y-08-01';
  }

  /// The last day of classes (YYYY-MM-DD).
  String lastClassworkDay() {
    final term = events.where((e) => e.kind == 'term').toList();
    final last = term.where((e) => e.title.toLowerCase().contains('last day'));
    String max(Iterable<String> ds) => (ds.toList()..sort()).last;
    if (last.isNotEmpty) return max(last.map((e) => e.last));
    if (term.isNotEmpty) return max(term.map((e) => e.last));
    return fmtDate(parseDate(semStart()).add(const Duration(days: 16 * 7)));
  }
}
