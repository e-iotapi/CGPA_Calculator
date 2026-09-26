import 'package:hive/hive.dart';

// Hive typeIds 1–3; Course is 0. Adapters are written by hand so no build
// step is needed. Field numbers are permanent — add, never renumber. Later
// fields go at the end of an Evaluative and are read only when present.

/// One marked piece of an evaluative, e.g. "CPU Scheduling" 8 / 10.
class EvalPart {
  EvalPart({
    required this.name,
    this.marks,
    required this.outOf,
    this.date,
    this.average,
  });

  /// "" for a single-mark evaluative.
  String name;

  /// Null until graded; never counted while null.
  double? marks;
  double outOf;

  /// ISO-8601 date string ("2026-09-26"), never a DateTime (§2.3).
  String? date;

  /// The class average for this part, on its own scale.
  double? average;

  /// The same part, unmarked: structure and out-of, never the marks.
  EvalPart blank() => EvalPart(name: name, outOf: outOf);

  Map<String, dynamic> toJson() => {
    'n': name,
    'm': marks,
    'o': outOf,
    'd': date,
    if (average != null) 'a': average,
  };

  static EvalPart fromJson(Map m) => EvalPart(
    name: m['n'] as String? ?? '',
    marks: (m['m'] as num?)?.toDouble(),
    outOf: (m['o'] as num).toDouble(),
    date: m['d'] as String?,
    average: (m['a'] as num?)?.toDouble(),
  );
}

/// A component of a course: an assignment, a quiz series, the mid-sem…
class Evaluative {
  Evaluative({
    required this.courseId,
    required this.name,
    required this.weight,
    required this.parts,
    this.countBest = 0,
    this.average,
  });

  String courseId;
  String name;

  /// Percent of the course, or raw marks in total-marks mode.
  double weight;

  /// One entry for a single-mark evaluative.
  List<EvalPart> parts;

  /// 0 = every part counts, else the best N.
  int countBest;

  /// The class average for the whole component, as typed; on the
  /// component's own scale (the sum of its parts' out-of).
  double? average;

  Map<String, dynamic> toJson() => {
    't': 'eval',
    'c': courseId,
    'n': name,
    'w': weight,
    'p': [for (final p in parts) p.toJson()],
    'b': countBest,
    if (average != null) 'a': average,
  };

  static Evaluative fromJson(Map m) => Evaluative(
    courseId: m['c'] as String,
    name: m['n'] as String,
    weight: (m['w'] as num).toDouble(),
    parts: [for (final p in m['p'] as List) EvalPart.fromJson(p as Map)],
    countBest: (m['b'] as num?)?.toInt() ?? 0,
    average: (m['a'] as num?)?.toDouble(),
  );
}

/// How a course is marked, and the optional class average.
class CourseConfig {
  CourseConfig({
    required this.courseId,
    this.weighted = true,
    this.courseTotal = 100,
    this.displayOutOf = 100,
    this.classAverage,
  });

  String courseId;

  /// True: each component has a % weight. False: one big total of marks.
  bool weighted;

  /// What the whole course is marked out of (100 when weighted).
  double courseTotal;

  /// The scale shown, e.g. 100 for a course marked out of 300.
  double displayOutOf;

  /// For the same components the user has entered, on the running total's
  /// scale. Null = no comparison anywhere.
  double? classAverage;

  Map<String, dynamic> toJson() => {
    't': 'config',
    'c': courseId,
    'w': weighted,
    'tot': courseTotal,
    'd': displayOutOf,
    'a': classAverage,
  };

  static CourseConfig fromJson(Map m) => CourseConfig(
    courseId: m['c'] as String,
    weighted: m['w'] as bool? ?? true,
    courseTotal: (m['tot'] as num?)?.toDouble() ?? 100,
    displayOutOf: (m['d'] as num?)?.toDouble() ?? 100,
    classAverage: (m['a'] as num?)?.toDouble(),
  );
}

/// Anything stored in marksBox, from its JSON form.
Object marksFromJson(Map m) =>
    m['t'] == 'config' ? CourseConfig.fromJson(m) : Evaluative.fromJson(m);

class EvaluativeAdapter extends TypeAdapter<Evaluative> {
  @override
  final int typeId = 1;
  @override
  Evaluative read(BinaryReader r) {
    final e = Evaluative(
      courseId: r.readString(),
      name: r.readString(),
      weight: r.readDouble(),
      parts: r.readList().cast<EvalPart>(),
      countBest: r.readInt(),
    );
    // Averages came later: an older record simply ends here.
    if (r.availableBytes > 0) {
      e.average = (r.read() as num?)?.toDouble();
      final partAverages = r.readList();
      for (final (i, a) in partAverages.indexed) {
        if (i < e.parts.length) e.parts[i].average = (a as num?)?.toDouble();
      }
    }
    return e;
  }

  @override
  void write(BinaryWriter w, Evaluative e) {
    w
      ..writeString(e.courseId)
      ..writeString(e.name)
      ..writeDouble(e.weight)
      ..writeList(e.parts)
      ..writeInt(e.countBest)
      ..write(e.average)
      ..writeList([for (final p in e.parts) p.average]);
  }
}

class EvalPartAdapter extends TypeAdapter<EvalPart> {
  @override
  final int typeId = 2;
  @override
  EvalPart read(BinaryReader r) => EvalPart(
    name: r.readString(),
    marks: (r.read() as num?)?.toDouble(),
    outOf: r.readDouble(),
    date: r.read() as String?,
  );
  @override
  void write(BinaryWriter w, EvalPart p) {
    w
      ..writeString(p.name)
      ..write(p.marks)
      ..writeDouble(p.outOf)
      ..write(p.date);
  }
}

class CourseConfigAdapter extends TypeAdapter<CourseConfig> {
  @override
  final int typeId = 3;
  @override
  CourseConfig read(BinaryReader r) => CourseConfig(
    courseId: r.readString(),
    weighted: r.readBool(),
    courseTotal: r.readDouble(),
    displayOutOf: r.readDouble(),
    classAverage: (r.read() as num?)?.toDouble(),
  );
  @override
  void write(BinaryWriter w, CourseConfig c) {
    w
      ..writeString(c.courseId)
      ..writeBool(c.weighted)
      ..writeDouble(c.courseTotal)
      ..writeDouble(c.displayOutOf)
      ..write(c.classAverage);
  }
}

void registerMarksAdapters() {
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(EvaluativeAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(EvalPartAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CourseConfigAdapter());
}
