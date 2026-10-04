import 'package:cgpa_calculator/core/cache/cache_first.dart';
import 'package:cgpa_calculator/core/heads/paths.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One row of the leaderboard: usernames only, never email or name. tag
/// is the branch code, present for admins, presidents and secretaries.
typedef LeaderEntry = ({String username, int points, String? tag});

/// `leaderboard/<campus>`: one read per view.
class LeaderboardStore {
  LeaderboardStore(this.db);

  /// The Firestore instance read.
  final FirebaseFirestore db;

  /// Everyone on [campus] with points, highest first (ties by name).
  Future<List<LeaderEntry>> of(String campus) async =>
      cacheFirst<List<LeaderEntry>>(
        key: 'lb|$campus',
        maxAge: const Duration(minutes: 10),
        version: await markerOf(db, campus, Paths.leaderboard),
        fetch: () async {
          final m = (await db.collection('leaderboard').doc(campus).get()).data();
          final p = (m?['p'] as Map?) ?? const {};
          final tags = (m?['tags'] as Map?) ?? const {};
          return [
            for (final e in p.entries)
              (
                username: '${e.key}',
                points: (e.value as num).toInt(),
                tag: tags['${e.key}'] as String?,
              ),
          ]..sort((a, b) {
            final d = b.points - a.points;
            return d != 0 ? d : a.username.compareTo(b.username);
          });
        },
        encode:
            (l) => [
              for (final e in l)
                {'u': e.username, 'p': e.points, 't': e.tag},
            ],
        decode: _decode,
      );

  static List<LeaderEntry> _decode(Object? o) => [
    for (final m in o as List)
      (
        username: (m as Map)['u'] as String,
        points: (m['p'] as num).toInt(),
        tag: m['t'] as String?,
      ),
  ];

  /// The saved [of], read synchronously.
  List<LeaderEntry>? peek(String campus) => peekCache('lb|$campus', _decode);
}
