import 'dart:io';

import 'package:cgpa_calculator/app/router.dart';
import 'package:cgpa_calculator/core/models/programmes.dart';
import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:cgpa_calculator/features/setup/degree_setup_page.dart';
import 'package:cgpa_calculator/features/setup/owner_setup_page.dart';
import 'package:cgpa_calculator/script.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('owner setup saves campus and batch', () async {
    final dir = await Directory.systemTemp.createTemp('hive_owner');
    Hive.init(dir.path);
    addTearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
      app.campus = null;
    });
    await saveCampusAndBatch(Campus.dubai, 2022);
    final box = Hive.box('settingsBox');
    expect(box.get('campus'), 'dubai');
    expect(box.get('batch'), 22);
    expect(app.campus, Campus.dubai);
    expect(app.batch, 22);
  });

  test('a non-BITS owner lands on owner setup', () {
    const owner = MyRoles(email: 'owner.pointer@example.com', owner: true);
    expect(ownerSetupNeeded(owner, owner.email, null), isTrue);
    expect(ownerSetupNeeded(owner, owner.email, 'goa'), isFalse);
    expect(
      ownerSetupNeeded(owner, 'f20230123@goa.bits-pilani.ac.in', null),
      isFalse,
    );
    expect(
      ownerSetupNeeded(
        const MyRoles(email: 'x@example.com'),
        'x@example.com',
        null,
      ),
      isFalse,
    );
    ownerSetupDue.value = true;
    addTearDown(() => ownerSetupDue.value = false);
    expect(profileGate(Routes.home), '/setup/owner');
    expect(profileGate(Routes.ownerSetup), isNull);
  });
}
