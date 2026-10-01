import 'dart:async';

import 'package:cgpa_calculator/core/platform/online.dart' as net;
import 'package:flutter/foundation.dart';

/// One level: independent jobs that run together.
typedef PrefetchLevel = List<Future<void> Function()>;

Future<void>? _once;

/// Forgets the session's run, for tests.
@visibleForTesting
void resetPrefetch() => _once = null;

/// Runs [levels] in order after [delay], each level's jobs together, each
/// job's failure dropped; [gap] between jobs of the last level (admin). Waits
/// while offline (resumes on [onlineChanges]). Runs once per session: a
/// second call returns the first's future.
Future<void> runPrefetch(
  List<PrefetchLevel> levels, {
  Duration delay = const Duration(seconds: 2),
  Duration gap = const Duration(milliseconds: 400),
  bool Function()? online,
  Stream<bool>? onlineChanges,
}) =>
    _once ??= () async {
      await Future<void>.delayed(delay);
      if (!(online ?? () => net.isOnline)()) {
        await (onlineChanges ?? net.onlineChanges).firstWhere((up) => up);
      }
      Future<void> run(Future<void> Function() job) async {
        try {
          await job();
        } catch (_) {}
      }

      for (var i = 0; i < levels.length; i++) {
        if (i == levels.length - 1 && i > 0) {
          for (final job in levels[i]) {
            await run(job);
            await Future<void>.delayed(gap);
          }
        } else {
          await Future.wait(levels[i].map(run));
        }
      }
    }();
