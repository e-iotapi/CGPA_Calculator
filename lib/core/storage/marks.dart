import 'package:cgpa_calculator/core/grading/marks.dart';
import 'package:cgpa_calculator/core/models/marks.dart';
import 'package:hive/hive.dart';

/// Evaluatives and course configs, keyed `eval:<courseId>:<n>` and
/// `config:<courseId>`. Registered with sync in lib/sync.dart (§2.4).
const marksBoxName = 'marksBox';

Box get _box => Hive.box(marksBoxName);

/// [courseId]'s evaluatives with their keys, in the order added.
List<(String, Evaluative)> evaluativesFor(String courseId) => [
  for (final k in _box.keys)
    if (k is String && k.startsWith('eval:$courseId:'))
      if (_box.get(k) case final Evaluative e) (k, e),
]..sort((a, b) => _seq(a.$1).compareTo(_seq(b.$1)));

int _seq(String key) => int.tryParse(key.split(':').last) ?? 0;

/// Every evaluative, for the calendar.
List<Evaluative> allEvaluatives() => [
  for (final v in _box.values)
    if (v is Evaluative) v,
];

/// Saves under [key], or a new key when null. Returns the key.
Future<String> saveEvaluative(Evaluative e, {String? key}) async {
  key ??= 'eval:${e.courseId}:${DateTime.now().microsecondsSinceEpoch}';
  await _box.put(key, e);
  return key;
}

/// Seeded on an ordinary course when it is added, with weights at 0 so the
/// "% still unassigned" line asks for them rather than a guess skewing the
/// total. A scheme the class publishes, or anything the user edits, wins.
const defaultComponents = ['Quiz 1', 'Quiz 2', 'Midsem', 'Compre'];

/// Courses with no quizzes: projects, Practice School, theses, seminars,
/// study and reading courses.
final _noQuizzes = RegExp(
  r'project|practice\s*school|thesis|seminar|study|reading',
  caseSensitive: false,
);

bool takesDefaultComponents(String title) => !_noQuizzes.hasMatch(title);

/// Seeds [defaultComponents] on [courseId] when it takes them and has no
/// marks data at all. Never overwrites.
Future<void> seedDefaultComponents(String courseId, String title) async {
  if (!Hive.isBoxOpen(marksBoxName) || !takesDefaultComponents(title)) return;
  if (configFor(courseId) != null || evaluativesFor(courseId).isNotEmpty) {
    return;
  }
  // Explicit keys: on the web the clock ticks in milliseconds, so four saves
  // in a row could share one.
  final base = DateTime.now().microsecondsSinceEpoch;
  for (final (i, name) in defaultComponents.indexed) {
    await saveEvaluative(
      Evaluative(
        courseId: courseId,
        name: name,
        weight: 0,
        parts: [EvalPart(name: '', outOf: 0)],
      ),
      key: 'eval:$courseId:${base + i}',
    );
  }
}

Future<void> deleteEvaluative(String key) => _box.delete(key);

CourseConfig? configFor(String courseId) {
  final v = _box.get('config:$courseId');
  return v is CourseConfig ? v : null;
}

Future<void> saveConfig(CourseConfig c) => _box.put('config:${c.courseId}', c);

MarksSummary summaryFor(String courseId) => MarksSummary([
  for (final (_, e) in evaluativesFor(courseId)) e,
], configFor(courseId));

/// Class-average delta per course id, only where one exists.
Map<String, double> classDeltas() {
  if (!Hive.isBoxOpen(marksBoxName)) return {};
  final ids = {
    for (final k in _box.keys)
      if (k is String && k.startsWith('config:')) k.substring(7),
  };
  return {
    for (final id in ids)
      if (summaryFor(id).classDelta case final d?) id: d,
  };
}
