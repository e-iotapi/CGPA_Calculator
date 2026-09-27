/// Who the signed-in person is acting as, this session and on this device
/// (ARCHITECTURE.md §16.3 fixes 1 and 15). Nothing here grants anything: the
/// rules check every write against the person's own grants.
library;

import 'dart:convert';

import 'package:cgpa_calculator/core/roles/capabilities.dart';
import 'package:cgpa_calculator/core/roles/role_store.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/core/storage/cache_boxes.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Set at startup once signed in; null in tests and signed out.
RoleStore? roleStore;

/// What the signed-in person holds. Restored from the device at start and
/// refreshed in the background.
final myRoles = ValueNotifier<MyRoles>(MyRoles.none);

/// An owner's lens (Open as): which role the app renders as. In memory for
/// the session only.
@immutable
class ViewAs {
  const ViewAs(this.role, {this.campus, this.scope});
  final Role role;
  final String? campus;

  /// A department key for a president, a course id for a CR.
  final String? scope;

  String get label => switch (role) {
    Role.owner => 'Owner',
    Role.admin => 'Admin',
    Role.president => 'President · $scope ${campusName(campus ?? '')}',
    Role.cr => 'CR · $scope ${campusName(campus ?? '')}',
    Role.student => 'Student',
  };
}

final viewAs = ValueNotifier<ViewAs?>(null);

/// The signed-in uid: the salt of every pseudonymous id (reviews, votes,
/// reports), never stored beside them. Set at startup.
String? myUid;

Box? get _device =>
    Hive.isBoxOpen(deviceBoxName) ? Hive.box(deviceBoxName) : null;

Future<void> openDeviceBox() => Hive.openBox(deviceBoxName);

/// The grant id Pointer opens as (Switch role), or null for Student. A grant
/// that has lapsed reads as Student.
final workingAs = ValueNotifier<Grant?>(null);

Future<void> setWorkingAs(Grant? g) async {
  workingAs.value = g;
  await _device?.put('workingAs', g?.id);
}

/// The audit entry's role for a write made now.
({String role, String? viewingAs}) actingNow() {
  final r = myRoles.value;
  final w = workingAs.value;
  final role =
      r.owner
          ? 'owner'
          : w != null
          ? (w.role == GrantRole.dept ? 'president' : w.role.key)
          : r.top.name;
  return (role: role, viewingAs: viewAs.value?.label);
}

void _use(MyRoles r) {
  myRoles.value = r;
  final id = _device?.get('workingAs');
  workingAs.value = r.grants.where((g) => g.id == id).firstOrNull;
  if (!r.owner) viewAs.value = null;
}

/// The last known roles, for an instant start (and offline).
void restoreMyRoles() {
  final raw = _device?.get('roles');
  if (raw is! String) return;
  try {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    _use(
      MyRoles(
        email: m['email'] as String,
        owner: m['owner'] as bool,
        grants: [
          for (final g in m['grants'] as List)
            if (Grant.fromMap(Map<String, dynamic>.from(g as Map)) case final x
                when x.liveAt(DateTime.now()))
              x,
        ],
      ),
    );
  } on Object catch (e) {
    debugPrint('[Pointer roles] cached roles unreadable: $e');
  }
}

/// Reads the person's roles again. Offline, keeps what it had.
Future<void> refreshMyRoles() async {
  final store = roleStore;
  if (store == null) return;
  try {
    final r = await store.loadMine();
    _use(r);
    await _device?.put(
      'roles',
      jsonEncode({
        'email': r.email,
        'owner': r.owner,
        'grants': [
          for (final g in r.grants)
            {
              'role': g.role.key,
              'email': g.email,
              'name': g.name,
              'campus': g.campus,
              'scope': g.scope,
              'programme': g.programme,
              'active': g.active,
              'expiresAt': g.expiresAt.millisecondsSinceEpoch,
            },
        ],
      }),
    );
  } on Object catch (e) {
    debugPrint('[Pointer roles] refresh failed: $e');
  }
}
