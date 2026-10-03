// User prefs (BUILDOUT_CONTRACTS.md B1): two bool flags on users/{uid}.prefs,
// mirrored in deviceBox so reads are synchronous and work offline.
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

const _kOffshoot = 'offshootHidden';
const _kTour = 'tourSeen';

/// The Offshoot tab's hidden flag, for Home to listen to. Set by
/// [PrefsStore] only; read straight from deviceBox when the store is built.
final offshootHiddenNow = ValueNotifier<bool>(false);

/// The signed-in user's store; set in `startApp`, null before.
PrefsStore? prefsStore;

class PrefsStore {
  PrefsStore(this.db, {required this.uid}) {
    offshootHiddenNow.value = offshootHidden;
  }

  final FirebaseFirestore db;
  final String uid;

  Box? get _box =>
      Hive.isBoxOpen(deviceBoxName) ? Hive.box(deviceBoxName) : null;

  bool _get(String k) => _box?.get('pref.$k') == true;

  bool get offshootHidden => _get(_kOffshoot);
  bool get tourSeen => _get(_kTour);

  Future<void> setOffshootHidden(bool v) => _set(_kOffshoot, v);
  Future<void> setTourSeen(bool v) => _set(_kTour, v);

  /// Local value first (it stands whatever the server says), then the merge.
  Future<void> _set(String k, bool v) async {
    await _box?.put('pref.$k', v);
    if (k == _kOffshoot) offshootHiddenNow.value = v;
    try {
      await merge(k, v);
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'not-found') return;
      // No user doc yet (first sync push not made): the rules refuse the
      // create. The local value stands and the next pull/set retries.
      if (e.code == 'permission-denied' && !await docExists()) return;
      rethrow;
    }
  }

  @visibleForTesting
  Future<void> merge(String k, bool v) => db.collection('users').doc(uid).set({
    'prefs': {k: v},
  }, SetOptions(merge: true));

  @visibleForTesting
  Future<bool> docExists() async {
    try {
      return (await db.collection('users').doc(uid).get()).exists;
    } on FirebaseException {
      return true; // cannot tell: let the original error surface
    }
  }

  /// Takes the server's flags into deviceBox. Offline or no doc: no change.
  Future<void> pull() async {
    try {
      final s = await db.collection('users').doc(uid).get();
      final p = s.data()?['prefs'];
      if (p is! Map) return;
      for (final k in [_kOffshoot, _kTour]) {
        if (p[k] is bool) await _box?.put('pref.$k', p[k]);
      }
      offshootHiddenNow.value = offshootHidden;
    } on FirebaseException {
      // unavailable, or not signed in yet: keep what the device has.
    }
  }
}
