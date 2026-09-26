import 'dart:io';

import 'package:cgpa_calculator/course.dart';

/// Anonymised real transcript. Kept out of git; see .gitignore.
final transcriptFile = File('test/fixtures/transcript.csv');

String? get transcriptSkip =>
    transcriptFile.existsSync()
        ? null
        : 'test/fixtures/transcript.csv not present';

List<Course> loadTranscript() => [
  for (final l in transcriptFile.readAsLinesSync().skip(1))
    if (l.trim().isNotEmpty)
      () {
        final f = l.split(',');
        return Course(
          title: '',
          id: f[0],
          sem: f[1],
          credits: double.parse(f[2]),
          discipline: f[3],
          elective: f[4],
          grade1: int.parse(f[5]),
          grade2: int.parse(f[6]),
        );
      }(),
];
