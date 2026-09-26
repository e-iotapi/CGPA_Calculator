import 'dart:convert';

import 'package:cgpa_calculator/core/grading/requirements.dart';
import 'package:hive/hive.dart';

// JSON-safe values only: settingsBox is JSON-encoded by sync (§2.3).

Box get _settings => Hive.box('settingsBox');

/// The CGPA the user is aiming for, or null if never set.
double? get statsTarget {
  final v = _settings.get('stats_target');
  return v is num ? v.toDouble() : null;
}

Future<void> setStatsTarget(double v) => _settings.put('stats_target', v);

/// Planned SGPA per future semester.
Map<String, double> get statsPlan {
  final raw = _settings.get('stats_plan');
  if (raw is! String || raw.isEmpty) return {};
  try {
    return {
      for (final e in (jsonDecode(raw) as Map).entries)
        if (e.value is num) e.key as String: (e.value as num).toDouble(),
    };
  } catch (_) {
    return {};
  }
}

Future<void> setStatsPlan(Map<String, double> plan) =>
    _settings.put('stats_plan', jsonEncode(plan));

/// Elective requirements from the last imported performance sheet.
DegreeNeeds? get degreeNeeds {
  final raw = _settings.get('degree_needs');
  if (raw is! String || raw.isEmpty) return null;
  try {
    return DegreeNeeds.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Future<void> setDegreeNeeds(DegreeNeeds n) =>
    _settings.put('degree_needs', jsonEncode(n.toJson()));
